#!/bin/bash

hostname=$(hostname);
user=<your_user>;
pass=<your_pass>;

aws_path=/usr/local/bin/aws;
aws_region="us-west-1";

cw_namespace="Tomcat DB Pool";
cw_metric_name="Utilization";

put_cw_metric() {
   pool=$1;
   value=$2;
   echo "value" "$value";
   $aws_path cloudwatch put-metric-data  --region=$aws_region --metric-name "$cw_metric_name" --namespace "$cw_namespace" --dimensions "hostname=$hostname,pool=$pool" --value "$value";
}

get_jmx_val() {
	clean=255;
	jdbcval=$1;
   att=$2;
   echo "";
   echo "******* START ******";
   echo "$jdbcval";
   echo "$att";
   val=$(curl -G -s -u $user:$pass -X GET  http://localhost:8080/manager/jmxproxy --data-urlencode qry=Catalina:type=DataSource,class=javax.sql.DataSource,name="${jdbcval}" | grep "${att}"|tr -d "\n"|tr -d "\r" );
	   IFS=', ' read -r -a array <<< "$val";
	   len=${#array[@]};
	   echo "len: $len";
	   clean=${array[$((len-1))]};	   
	   echo "clean1: $clean";
   echo "clean2: $clean";
   echo "**** END ****";
   echo "";
   return $clean;
}

get_jmx() {
   get_jmx_val "$1" "maxActive:\|maxTotal:";
   maxActive=$?;
   echo "maxActive: $maxActive";
   get_jmx_val "$1" "active:\|numActive:";
   active=$?;
   echo "active: $active";
   used=$((100*active/maxActive));
   echo "metric: $used";
   put_cw_metric "$1" "$used";
}

while read -r line; do 
   name=$(cut -d',' -f3 <<<"$line");
   tmp=$(cut -d'=' -f2 <<<"$name");
   jdbc=${tmp//[[:space:]]/};
   echo "iter $jdbc";
   get_jmx "$jdbc";
done < <( curl -s -u $user:$pass -X GET  http://localhost:8080/manager/jmxproxy --data-urlencode qry="Catalina:type=DataSource,class=javax.sql.DataSource,name=*"|grep '^Name: Catalina:type=DataSource,class=javax.sql.DataSource,name=".*"[[:cntrl:]]*$')
