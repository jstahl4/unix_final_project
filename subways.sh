cat status.txt | tr "\n" "|" | grep -o "<subway>.*</subway>" | tr "|" "\n"
