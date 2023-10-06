#!/usr/bin/perl -w
#=============================================================================== 
# Script Name   : check_scaleway_bddredis.pl
# Usage Syntax  : check_scaleway_bddredis.pl -T <Token> -z <Scaleway zone> -N <cluster name> | -i <id> | -L [-m <Metric_Name> -w <threshold> -c <threshold> ]
# Version       : 1.0.2
# Last Modified : 06/10/2023
# Modified By   : Start81 (J DESMAREST) 
# Description   : This is a Nagios check that uses Scaleway s REST API to get redis bdd metrics
# Depends On    :  Monitoring::Plugin  Data::Dumper JSON  REST::Client  Readonly File::Basename
# 
# Changelog: 
#    Legend: 
#       [*] Informational, [!] Bugfix, [+] Added, [-] Removed 
#  - 21/06/2023| 1.0.0 | [*] First release
#  - 30/06/2023| 1.0.1 | [*] Add Filter on metric rest query
#  - 06/10/2023| 1.1.2 | [*] clean-up code
#===============================================================================

use strict;
use warnings;
use Monitoring::Plugin;
use Data::Dumper;
use REST::Client;
use JSON;
use utf8; 
use Getopt::Long;
use LWP::UserAgent;
use Readonly;
use File::Basename;
Readonly our $VERSION => "1.0.2";
my %state  =("ready"=>0, 
"provisioning"=>0,
"configuring"=>0, 
"deleting"=>2, 
"error"=>2, 
"autohealing"=>0, 
"locked"=>2, 
"initializing"=>0, 
"suspended"=>2,  
"restarting"=>0);
my $me = basename($0);
my $o_verb;
sub verb { my $t=shift; print $t,"\n" if ($o_verb) ; return 0}
my $np = Monitoring::Plugin->new(
    usage => "Usage: %s  -T <Token> -z <Scaleway zone> -N <cluster name> | -i <id> | -L [-m <Metric_Name> -w <threshold> -c <threshold> ]\n",
    plugin => $me,
    shortname => " ",
    blurb => "$me is a Nagios check that uses Scaleway s REST API to get redis bdd metrics and status",
    version => $VERSION,
    timeout => 30
);
$np->add_arg(
    spec => 'Token|T=s',
    help => "-T, --Token=STRING\n"
          . ' Token for api authentication',
    required => 1
);
$np->add_arg(
    spec => 'name|N=s',
    help => "-N, --name=STRING\n"
          . '   cluster name',
    required => 0
);
$np->add_arg(
    spec => 'id|i=s',
    help => "-i, --id=STRING\n"
          . '   cluster id',
    required => 0
);
$np->add_arg(
    spec => 'apiversion|a=s',
    help => "-a, --apiversion=string\n"
          . '  Scaleway API version',
    required => 1,
    default => 'v1'
);
$np->add_arg(
    spec => 'warning|w=s',
    help => "-w, --warning=threshold\n" 
          . '   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.',
);
$np->add_arg(
    spec => 'critical|c=s',
    help => "-c, --critical=threshold\n"  
          . '   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.',
);
$np->add_arg(
    spec => 'listInstance|L',
    help => "-L, --listInstance\n"  
          . '   Autodiscover instance',

);
$np->add_arg(
    spec => 'zone|z=s',
    help => "-z, --zone=STRING\n"
          . '  Scaleway zone',
    required => 1
);
$np->add_arg(
    spec => 'metric|m=s',
    help => "-m, --metric=STRING\n"
          . '  bdd metrics : cpu_usage_percent | mem_usage_percent | db_memory_usage_percent ',
    required => 0
);
my @criticals = ();
my @warnings = ();
my @ok = ();
$np->getopts;
my $o_token = $np->opts->Token;
my $o_apiversion = $np->opts->apiversion;
my $o_list_clusters = $np->opts->listInstance;
my $o_id = $np->opts->id;
$o_verb = $np->opts->verbose;
my $o_warning = $np->opts->warning;
my $o_critical = $np->opts->critical;
my $o_reg = $np->opts->zone;
my $o_timeout = $np->opts->timeout;
my $o_metric = $np->opts->metric;
my $o_name = $np->opts->name;
#Check parameters
if ((!$o_list_clusters) && (!$o_name) && (!$o_id)) {
    $np->plugin_die("Cluster name or id missing");
}
if (!$o_reg)
{
    $np->plugin_die("region missing");
}
if ($o_timeout > 60){
    $np->plugin_die("Invalid time-out");
}

#Rest client Init
my $client = REST::Client->new();
$client->setTimeout($o_timeout);
my $url ;
#Header
$client->addHeader('Content-Type', 'application/json;charset=utf8');
$client->addHeader('Accept', 'application/json');
$client->addHeader('Accept-Encoding',"gzip, deflate, br");
#Add authentication
$client->addHeader('X-Auth-Token',$o_token);
my $id; #id clusters
my $i; 
if (!$o_id){
    #https://api.scaleway.com/redis/v1/regions/fr-par/clusters
    $url = "https://api.scaleway.com/redis/$o_apiversion/zones/$o_reg/clusters";
    my %clusters;
    my $instance;
    verb($url);
    $client->GET($url);
    if($client->responseCode() ne '200'){
        $np->plugin_exit('UNKNOWN', " response code : " . $client->responseCode() . " Message : Error when getting instance list". $client->{_res}->decoded_content );
    }
    my $rep = $client->{_res}->decoded_content;
    my $clusters_list_json = from_json($rep);
    verb(Dumper($clusters_list_json));
    my $total_instance_count = $clusters_list_json->{'total_count'};
    verb("Total clusters count : $total_instance_count\n");
    $i = 0;
    while (exists ($clusters_list_json->{'clusters'}->[$i])){
        $instance = q{};
        $id = q{};
        $instance = $clusters_list_json->{'clusters'}->[$i]->{'name'};
        $id = $clusters_list_json->{'clusters'}->[$i]->{'id'}; 
        $clusters{$instance}=$id;
        $i++;
    }
    my @keys = keys %clusters;
    my $size;
    $size = @keys;
    verb ("hash size : $size\n");
    if (!$o_list_clusters){
        #If instance name not found
        if (!defined($clusters{$o_name})) {
            my $list="";
            my $key ="";
            #format a instance list
            $list = join(', ', @keys );
            $np->plugin_exit('UNKNOWN',"instance $o_name not found the clusters list is $list"  );
        }
    } else {
        #Format autodiscover Xml for centreon
        my $xml='<?xml version="1.0" encoding="utf-8"?><data>'."\n";
        foreach my $key (@keys) {
            $xml = $xml . '<label name="' . $key . '"id="'. $clusters{$key} . '"/>' . "\n"; 
        }
        $xml = $xml . "</data>\n";
        print $xml;
        exit 0;
    }
    # inject id in api url
    verb ("Found id : $clusters{$o_name}\n");
    $id = $clusters{$o_name};
};

$id = $o_id if (!$id);
verb ("id = $id\n");


#Getting cluster info
my $a_instance_url = "https://api.scaleway.com/redis/$o_apiversion/zones/$o_reg/clusters/$id";
my $instance_json;
my $rep_instance ;
verb($a_instance_url);
$client->GET($a_instance_url);
if($client->responseCode() ne '200'){
    $np->plugin_exit(UNKNOWN, " response code : " . $client->responseCode() . " Message : Error when getting instance". $client->{_res}->decoded_content );
}
$rep_instance = $client->{_res}->decoded_content;
$instance_json = from_json($rep_instance);
verb(Dumper($instance_json));
#my $engine = $instance_json->{'engine'};
my $status = $instance_json->{'status'};
my $name =  $instance_json->{'name'};
my $rep_metric;
my $max_connexions = 0;
my $msg= "Cluster status $status name $name id = $id";
#If state in not defined in %state then return critical
if (!exists $state{$status} ){
    push( @criticals," State $status is UNKNOWN "); 
} else {
    push( @criticals,$msg) if ($state{$status}== 2);
}
#Metric
if ($o_metric) {
    my $metric_url = "https://api.scaleway.com/redis/$o_apiversion/zones/$o_reg/clusters/$id/metrics?metric_name=$o_metric";
    verb($metric_url);
    $client->GET($metric_url);
    if($client->responseCode() ne '200'){
        $np->plugin_exit(UNKNOWN, " response code : " . $client->responseCode() . " Message : Error when getting instance". $client->{_res}->decoded_content );
    }
    $rep_metric = $client->{_res}->decoded_content;
    my $metric_json = from_json($rep_metric);
    verb(Dumper($metric_json));
    $i=0;
    my @metric_list;
    my %metrics_redis;
    my $metric_founded=0;
    my $node;
    my $metric;
    while (exists ($metric_json->{'timeseries'}->[$i])){

        if ($o_metric eq $metric_json->{'timeseries'}->[$i]->{'name'}){
            $node = q{};
            $metric = q{};
            $node = $metric_json->{'timeseries'}->[$i]->{'metadata'}->{'node'};
            $metric = $metric_json->{'timeseries'}->[$i]->{'points'}->[0]->[1];
            $metrics_redis{$node} = sprintf("%.3f",$metric);
            $metric_founded++;

        } 
        $i++;
    }  
    $np->plugin_exit('UNKNOWN', "Metric not found available metric are :". join(', ', @metric_list)) if ($metric_founded==0);
    $msg = $name;
    my @keys = keys %metrics_redis;
    #format result
    my @tmp = ();
    foreach my $key (@keys) {
        @tmp = split(' ',$key);
        $msg = "$msg $key  $o_metric = " . $metrics_redis{$key} . "%";
        $np->add_perfdata(label => "$o_metric"."_". $tmp[1], value => $metrics_redis{$key}, uom => "%", warning => $o_warning, critical => $o_critical);
            if ((defined($np->opts->warning) || defined($np->opts->critical))) {
                $np->set_thresholds(warning => $o_warning, critical => $o_critical);
                my $test_metric = $np->check_threshold($metrics_redis{$key});
                push( @criticals, " $o_metric out of range value $metrics_redis{$key}") if ($test_metric==2);
                push( @warnings, " $o_metric out of range value $metrics_redis{$key}") if ($test_metric==1);
            } 
    }

    
}
$np->plugin_exit('CRITICAL', join(', ', @criticals)) if (scalar @criticals > 0);
$np->plugin_exit('WARNING', join(', ', @warnings)) if (scalar @warnings > 0);
$np->plugin_exit('OK', $msg );
