# Charles "Swerve" Carver
# James Stahl
#
# UNIX Final Project:
# MTA Status Display
# - Displays the statuses of several MTA lines
#
# Dependencies:
# - lynx

# it's a trap!
trap 'rm status.txt; rm s1.xml; rm s2.html; rm info.txt; rm s3.html; rm mta.txt; rm subways.txt; rm lines_status.txt; tput setab 0; tput setaf 7; clear; stty sane; exit;' SIGINT SIGQUIT SIGTERM

# set the terminal mode to allow for non-blocking input
# also don't want to echo any characters
stty -echo -icanon time 0 min 0

# color functions
red() {
	tput setab 1; tput setaf 0
}
yellow() {
	tput setab 3; tput setaf 0
}
green() {
	tput setab 2; tput setaf 0
}
reset() {
	tput setab 0; tput setaf 7;
}

# how long to pause for between checks, in second
delay=5

# box array dimensions
num_box_rows=3
num_box_cols=4

# box spacing and text spacing
margin=2
padding=2
textPadding=2

# window size
window_height=`tput lines`
window_width=`tput cols`

# calculate height and width of each box based on window size
box_height=$(($window_height - $margin - $(($padding * $num_box_rows))))
box_height=$(($box_height / $num_box_rows))
box_width=$(($window_width - $margin - $(($padding * $num_box_cols))))
box_width=$(($box_width / $num_box_cols))

# how far to move cursor to next box
width_increment=$(($box_width + $padding))
height_increment=$(($box_height + $padding * 1/2))

# starting cursor position
start_position=$(($margin))

# function to output the info
output() {

	# move cursor
	tput cup $(($cursor_row + $textPadding * 1/2)) $(($cursor_col + $textPadding))

	# output info
	echo $1

	# increment row
	cursor_row=$(($cursor_row + 1))
}

# compute the number of spaces needed per box/width only once
spaces=""
for c in `seq 0 $(($box_width - 1))`
do
	spaces+=" "
done

# function to draw a colored background
draw_background() {

	# iterate through rows
	for r in `seq 0 $(($box_height - 1))`; do

		# print each row with the predetermined number of spaces
		tput cup $(($cursor_row + $r)) $(($cursor_col))
		printf '%s' "$spaces"
	done
}

# function to write the info in the box
write_info() {

	# set cursor position
	cursor_row=$current_row
	cursor_col=$current_col

	# set background
	if [ "$status" == "GOOD SERVICE" ]
	then
		green
	else
		if [ "$status" == "DELAYS" ]
		then
			red
		else
			yellow
		fi
	fi

	# output colored background
	draw_background

	# output all info
	output "$line"
	output "$status"
	output "Press \"${fKeyNames[$fKeyIndex]}\" for more info"

	# reset background
	reset
}

# override flag will cancel out of the check_for_keypress loop when it equals 1
# this happens after a line's status has been checked, triggering a clearing of the screen and refresh of data
override=0

# a list of function keys to view more info per train line
# has more than enough values in case of future line additions
fKeyNames=("1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c")

# function that checks for a keypress
check_for_keypress() {

	# reset the status html variable
	status_html=""

	# read the input to the terminal
	read input
	if [[ "$input" == "q" ]]
	then

		# the user has decided to quit
		rm s1.xml; rm s2.html; rm info.txt; rm s3.html; rm mta.txt; rm subways.txt; rm lines_status.txt; rm status.txt;
		tput setab 0; tput setaf 7; clear; stty sane; exit;
	else

		# something else has been pressed
		# loop through the saved function key names and see if one of them was pressed
		line="-1"
		j=0
		for keyName in "${fKeyNames[@]}"
		do
			if [[ "$keyName" == "$input" ]]
			then

				# a key has been pressed corresponding to a specific line
				line=${lines[$j]}
				break
			fi
			j=$((j + 1))
		done

		# check if a line was registered
		if [ "$line" != "-1" ]
		then

			# parse the subways file for just the data pertaining to the specific line
			cat subways.txt | grep "<name>$line</name>" -B 1 -A 100000 | sed -n '/<line>/,/<\/line>/p;/<\/line>/q' > s1.xml

			# parse the line for only the text information
			cat s1.xml | sed -n '/<text>/,/<\/text>/p' | cut -d ">" -f2 | cut -d "<" -f1 > s2.html

			# create the info file
			echo "[LINE INFORMATION FOR $line]" > info.txt
			echo >> info.txt

			# check if there is text information or an empty text tag, <text />
			if [[ `cat s2.html | wc -l` -ge 1 ]]
			then

				# the text tag was not empty, convert the html characters to html with lynx
				lynx --dump s2.html > s3.html

				# now convert the html to text with lynx
				lynx --dump s3.html >> info.txt
			else

				# there was an empty text tag
				echo "No information to report" >> info.txt
			fi

			# output the data to a text file and display it with less
			echo >> info.txt
			echo "[PRESS \"q\" TO QUIT]" >> info.txt
			reset
			clear
			less info.txt

			# once less cancels, change the override flag to refresh the screen
			override=1
		fi
	fi
}

# clear the screen initially
clear

# loop infinitely to display the terminal
while true
do

	# reset coordinates and override flag
        current_row=$(($start_position + 2)) #reset + 2 to account for timestamp
        current_col=$start_position
	override=0

	# get the mta information from their "xml" (although it's not valid)
	wget -qO- http://web.mta.info/status/serviceStatus.txt > mta.txt

	# get the timestamp of the last updated data
	timestamp=`cat mta.txt | grep timestamp | cut -d ">" -f5 | cut -d "<" -f1`

	# parse out the non-subway related info
	cat mta.txt | tr "\n" "|" | grep -o "<subway>.*</subway>" | tr "|" "\n" > subways.txt

	# output a list of all the lines and their current statuses
	cat subways.txt | grep "<line>" -A 2 | cut -d ">" -f2 | cut -d "<" -f1 | grep '\S' | grep -v "^--$" > lines_status.txt

	# reset fKeyIndex, correspoding to the function key label's index and the train line's index
	fKeyIndex=0

	# reset i to 1 since awk indexing starts at 1
	i=1

	# reset the delay timer
	t=0

	# echo the last updated time
	tput cup $(($margin)) $(($margin))
	echo "last updated: $timestamp"

	# echo the quit message
	quit="press \"q\" to quit"
	tput cup $(($margin)) $(($window_width - ${#quit} - $margin))
	echo $quit

	# loop through each train line/status line
	while [ $i -le `wc -l < lines_status.txt` ]
	do

		# the train line resides on the (i)th line in the text file
		line=`awk -v i=$i 'NR==i' < lines_status.txt`

		# the train status resides on the (i+1)th line in the text file
		status=`awk -v i=$((i + 1)) 'NR==i' < lines_status.txt`

		# write the info to the display
		write_info

		# match the train line to the function key index
		lines[fKeyIndex]=$line

		# determine the current column and row
		current_col=$(($current_col + $width_increment))
        	if ! (($current_col + $box_width < $window_width));
		then
			current_col=$start_position
	               	current_row=$(($current_row + $height_increment))
        	fi

		# increment the index read from the satus text file by 2, since each trainline is 2 text lines away from the next
		i=$((i + 2))

		# increment the function key index
		fKeyIndex=$((fKeyIndex + 1))
	done

	# Reset the cursor position
	tput cup $window_height $window_width

	# check for a keypress at the end of the display
	endDate=$((`date +%s` + $delay))
	while [[ `date +%s` -lt $endDate ]] && [ $override -eq 0 ]
	do

		# increment time by 1
		t=$((t + 1))

		# do the checking
		check_for_keypress

		# sleep for 1 pseduo-m
		sleep 0.001
	done

done
