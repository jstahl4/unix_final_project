cat status.txt | grep timestamp | cut -d ">" -f5 | cut -d "<" -f1
