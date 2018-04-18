wget -qO- http://web.mta.info/status/serviceStatus.txt > mta.txt
cat mta.txt | tr "\n" "|" | grep -o "<subway>.*</subway>" | tr "|" "\n" > subways.txt
cat subways.txt | grep "<line>" -A 2 | cut -d ">" -f2 | cut -d "<" -f1 | grep '\S' | grep -v "^--$" > lines_status.txt 
i=1
while [ $i -le `wc -l < lines_status.txt` ]
do
	line=`awk -v i=$i 'NR==i' < lines_status.txt`
	status=`awk -v i=$((i + 1)) 'NR==i' < lines_status.txt`
	echo "$line, $status"
	i=$((i + 2))
done
