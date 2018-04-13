cat subways.txt | grep "<line>" -A 2 | cut -d ">" -f2 | cut -d "<" -f1 | grep '\S' | grep -v '^--$'
