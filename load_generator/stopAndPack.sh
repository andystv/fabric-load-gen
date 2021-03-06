#!/bin/bash

function make_exp_desc()
{
	exp_name=$1
	brief=$(awk -F":" '/brief/{print $2}' ./config.yaml)
	batchSize=$(awk '/MaxMessageCount/ {print $2}' ../../crypto-configtxgen/configtx.yaml)
	batchTimeout=$(awk '/BatchTimeout/ {print $2}' ../../crypto-configtxgen/configtx.yaml)
	runTime=$(awk '/loadDuration/ {print $2/60000 "min"}' ./config.yaml)
	numProcesses=$(awk '/numProcesses/ {print $2}' ./config.yaml)
	numClientsPerProcess=$(awk '/numClientsPerProcess/ {print $2}' ./config.yaml)
	inputRate=$(awk -v numClients=$((numClientsPerProcess*numProcesses)) '/numLocalRequestsPerSec/ {print $2*numClients,"Tx/s"}' ./config.yaml)
	openSystem=$(awk '/openSystem/ {print $2}' ./config.yaml)
	ordererType=$(awk '/OrdererType/ {print $2}' ../../crypto-configtxgen/configtx.yaml)

	cat > exp_desc.txt <<- EXP_DESC
	Experiment Number: $exp_name
	Brief Description: $brief
	Batch-Size: $batchSize
	Block-Cutoff: $batchTimeout
	Runtime: $runTime
	Number of Processes: $numProcesses
	Number of Clients per Process: $numClientsPerProcess
	Total input rate: $inputRate
	Open System: $openSystem
	Orderer Type: $ordererType
	EXP_DESC
}

echo "Stopping fetch-block"
pkill fetch-block

echo "Stopping network and resource capture"
../../stop-capture-resource-usage.sh

echo "Packing data"
cp *.txt logs/

# Generate nmoncharts
pushd logs
for i in peer{0..7} orderer0 kafka-zookeeper; do
	( cd $i
	  unzip data.zip
	  x=0
	  for j in *.nmon; do
	      ~/nmonchart/nmonchart $j r-util$x.html
	      x=$(($x+1))
	  done
	  zip -r data.zip *.html
	  rm *.log *.nmon *.txt *.html torch.svg
	) &
done

wait
popd

# Find the latest 'perfLogs' folder
latestFolder=$(ls -t ../../fetch-block/ | head -n1 | cut -f1 -d' ')
pushd ../../fetch-block/$latestFolder
../generate_useful_data.sh
popd

cp ../../fetch-block/$latestFolder/*.txt logs/
cp config.yaml logs/

oldLogName=$(ls -1 | grep exp_good | egrep -o "[0-9]+" | sort -nr | head -n1)

make_exp_desc $((oldLogName+1))
cp exp_desc.txt logs/

newLogName="exp_good_"$((oldLogName+1))".zip"
zip -r $newLogName logs
scp $newLogName root@9.126.108.106:/root/cendhu/experiment_data/$newLogName
echo Created $newLogName
