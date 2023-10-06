## check_scaleway_bddredis

This is a Nagios check that use Scalways's REST API to check if the Redis bdd is up and get metric [ALL][PERL]
https://www.scaleway.com/en/developers/api/managed-database-redis/
### prerequisites

This script uses theses libs : REST::Client, Data::Dumper, Monitoring::Plugin, JSON, Readonly

to install them type :

```
sudo cpan REST::Client Data::Dumper  Monitoring::Plugin JSON Readonly 
```

### Use case

```bash
check_scaleway_bddredis.pl 1.0.2

This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).

check_scaleway_bddredis1.pl is a Nagios check that uses Scaleway s REST API to get redis bdd metrics

Usage: check_scaleway_bddredis.pl  -T <Token> -z <Scaleway zone> -N <cluster name> | -i <id> | -L [-m <Metric_Name> -w <threshold> -c <threshold> ]

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html
   for usage and examples.
 -T, --Token=STRING
 Token for api authentication
 -N, --name=STRING
   cluster name
 -i, --id=STRING
   cluster id
 -a, --apiversion=string
  Scaleway API version
 -w, --warning=threshold
   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.
 -c, --critical=threshold
   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.
 -L, --listInstance
   Autodiscover instance
 -z, --zone=STRING
  Scaleway zone
 -m, --metric=STRING
  bdd metrics : cpu_usage_percent | mem_usage_percent | db_memory_usage_percent
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 30)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```

sample :

```bash
#list all database 
./check-scaleway-bddredis.pl -T <Token> -z fr-par-2 -L
#BDD sate
./check-scaleway-bddredis.pl -T <Token> -z fr-par-2 -N <InstanceName>
#get a metric
./check-scaleway-bddredis.pl -T <Token> -z fr-par-2 -N <InstanceName> -m cpu_usage_percent
./check-scaleway-bddredis.pl -T <Token> -z fr-par-2 -i <Id> -m cpu_usage_percent
```

Retour des commandes :

```bash
#list all database
<?xml version="1.0" encoding="utf-8"?><data>
<label name="<InstanceName>"id="<Id>"/>
</data>
#BDD sate
OK - Cluster status ready name <InstanceName> id = Id
#get a metric
OK - <InstanceName> node XXXXXX  cpu_usage_percent = 2.8166666 node XXXXXXX  cpu_usage_percent = 4.0583334 node XXXXXX  cpu_usage_percent = 2.1333334 | cpu_usage_percent_XXXXXX=2.8166666%;; cpu_usage_percent_XXXXXX=4.0583334%;; cpu_usage_percent_XXXXXX=2.1333334%;;
```
