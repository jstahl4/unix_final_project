# Charles "Swerve" Carver
# James "Poughkeepsie" Stahl
#
# UNIX Final Project: MTA Status Display
# - Displays the statuses of several MTA subway lines
# - Displays "more info" if any is available
#
# Dependencies:
# - lynx

# It's a trap!
trap 'rm status.txt; rm s1.xml; rm s2.html; rm info.txt; rm s3.html; rm mta.txt; rm subways.txt; rm lines_status.txt; tput setab 0; tput setaf 7; clear; stty sane; exit;' SIGINT SIGQUIT SIGTERM

# Set the terminal mode to allow for non-blocking input
# Also don't want to echo any characters on input
stty -echo -icanon time 0 min 0

# How long to pause for between in between data refreshes, in "seconds"
delay=5

# Box array dimensions
num_box_rows=3
num_box_cols=4

# Box spacing and text spacing
margin=2
padding=2
textPadding=2

# Window size
window_height=`tput lines`
window_width=`tput cols`

# Calculate height and width of each box based on window size
box_height=$(($window_height - $margin - $(($padding * $num_box_rows))))
box_height=$(($box_height / $num_box_rows))
box_width=$(($window_width - $margin - $(($padding * $num_box_cols))))
box_width=$(($box_width / $num_box_cols))

# How far to move cursor to next box
# The 1/2 makes the column spacing and row spacing equitable 
width_increment=$(($box_width + $padding))
height_increment=$(($box_height + $padding * 1/2))

# Starting cursor position
start_position=$(($margin))

# Override flag will cancel out of the check_for_keypress loop when it equals 1
# This happens after a line's status has been checked, triggering a clearing of the screen and refresh of data
override=0

# A list of function keys to view more info per train line
# Has more than enough values in case of future line additions
# ...but that hasn't happened in 80 years (minus line extensions)!
f_key_names=("1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c")

# Clear the screen at the start
clear

# Red color function
red() {
	tput setab 1; tput setaf 0
}

# Yellow color function
yellow() {
	tput setab 3; tput setaf 0
}

# Green color function
green() {
	tput setab 2; tput setaf 0
}

# Reset colors
reset() {
	tput setab 0; tput setaf 7;
}

# Function to output the info
output() {

	# Move cursor, also use that 1/2 again
	tput cup $(($cursor_row + $textPadding * 1/2)) $(($cursor_col + $textPadding))

	# Output info
	echo $1

	# Increment row
	cursor_row=$(($cursor_row + 1))
}

# Compute the number of spaces needed per box/width only once
spaces=""
for c in `seq 0 $(($box_width - 1))`
do
	spaces+=" "
done

# Function to draw a colored background
draw_background() {

	# Iterate through rows
	for r in `seq 0 $(($box_height - 1))`; do

		# Print each row with the predetermined number of spaces
		# This is much quicker than printing each column character by character
		tput cup $(($cursor_row + $r)) $(($cursor_col))
		printf '%s' "$spaces"
	done
}

# Function to write the info in the box
write_info() {

	# Set cursor position
	cursor_row=$current_row
	cursor_col=$current_col

	# Set background depending on the line's status
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

	# Output colored background
	draw_background

	# Output all info
	output "$line"
	output "$status"
	output "Press \"${f_key_names[$f_key_index]}\" for more info"

	# Reset background
	reset
}

# Function that checks for a keypress
check_for_keypress() {

	# Reset the status html variable
	status_html=""

	# Read the input to the terminal
	read input
	if [[ "$input" == "q" ]]
	then

		# The user decided to quit if they press "q"
		rm s1.xml; rm s2.html; rm info.txt; rm s3.html; rm mta.txt; rm subways.txt; rm lines_status.txt; rm status.txt;
		tput setab 0; tput setaf 7; clear; stty sane; exit;
	else

		# Something else was pressed
		# Loop through the saved function key names and see if one of them was pressed
		line="-1"
		j=0
		for key_name in "${f_key_names[@]}"
		do
			if [[ "$key_name" == "$input" ]]
			then

				# A key has been pressed corresponding to a specific line
				line=${lines[$j]}
				break
			fi
			j=$((j + 1))
		done

		# Check if a line was registered with that keypress
		if [ "$line" != "-1" ]
		then

			# Parse the subways file for just the data pertaining to the specific line
			# Slightly hacky-method by finding the subway line name, getting the row above it...
			# ...and including the remaining "100000" lines of the file to simulate reading until the end
			cat subways.txt | grep "<name>$line</name>" -B 1 -A 100000 | sed -n '/<line>/,/<\/line>/p;/<\/line>/q' > s1.xml

			# Parse the line for only the text information
			cat s1.xml | sed -n '/<text>/,/<\/text>/p' | cut -d ">" -f2 | cut -d "<" -f1 > s2.html

			# Create the info file
			echo "[LINE INFORMATION FOR $line]" > info.txt
			echo >> info.txt

			# Check if there is text information or an empty text tag, <text />
			if [[ `cat s2.html | wc -l` -ge 1 ]]
			then

				# The text tag was not empty, convert the html characters to actual html with lynx
				lynx --dump s2.html > s3.html

				# Now convert the html to text with lynx
				lynx --dump s3.html >> info.txt
			else

				# There was an empty text tag
				echo "No information to report" >> info.txt
			fi

			# Output the data to a text file
			echo >> info.txt
			echo "[PRESS \"q\" TO QUIT]" >> info.txt

			# Clear the screen
			reset
			clear

			# Output more info with less
			less info.txt

			# Once less exits, change the override flag to refresh the screen
			override=1
		fi
	fi
}

# Loop infinitely to display the terminal
while true
do

	# Reset coordinates and override flag
	# $current_row adds "2" to account for displaying the timestamp
    current_row=$(($start_position + 2)) 
    current_col=$start_position
	override=0

	# Get the mta information from their "xml" (although it's not valid)
	wget -qO- http://web.mta.info/status/serviceStatus.txt > mta.txt

	# Get the timestamp of the last updated data
	timestamp=`cat mta.txt | grep timestamp | cut -d ">" -f5 | cut -d "<" -f1`

	# Parse out the non-subway related info
	cat mta.txt | tr "\n" "|" | grep -o "<subway>.*</subway>" | tr "|" "\n" > subways.txt

	# Output a list of all the lines and their current statuses
	cat subways.txt | grep "<line>" -A 2 | cut -d ">" -f2 | cut -d "<" -f1 | grep '\S' | grep -v "^--$" > lines_status.txt

	# Reset fKeyIndex, correspoding to the function key label's index and the train line's index
	f_key_index=0

	# Reset i to 1 since awk indexing starts at 1 which is awkward (looking at you, MatLab)
	i=1

	# Echo the last updated time
	tput cup $(($margin)) $(($margin))
	echo "last updated: $timestamp"

	# Echo the quit message
	quit="press \"q\" to quit"
	tput cup $(($margin)) $(($window_width - ${#quit} - $margin))
	echo $quit

	# Loop through each train/status line
	while [ $i -le `wc -l < lines_status.txt` ]
	do

		# The train's linename resides on the (i)th line in the text file
		line=`awk -v i=$i 'NR==i' < lines_status.txt`

		# The train's status resides on the (i+1)th line in the text file
		status=`awk -v i=$((i + 1)) 'NR==i' < lines_status.txt`

		# Write the info to the display
		write_info

		# Match the train line to an arbitrary function key index
		lines[f_key_index]=$line

		# Determine the current column and row
		current_col=$(($current_col + $width_increment))
        if ! (($current_col + $box_width < $window_width))
		then
			current_col=$start_position
			current_row=$(($current_row + $height_increment))
        fi

		# Increment the index read from the satus text file by 2, since each trainline is 2 text lines away from the next
		i=$((i + 2))

		# Increment the function key index
		f_key_index=$((f_key_index + 1))
	done

	# Reset the cursor position
	tput cup $window_height $window_width

	# Check for a keypress at the end of the display
	# Compute the ending timestamp, aka current timestamp + $delay
	end_timestamp=$((`date +%s` + $delay))
	while [[ `date +%s` -lt $end_timestamp ]] && [ $override -eq 0 ]
	do

		# Check for a keypress
		check_for_keypress

		# Sleep for 1 pseduo-miliseconds
		sleep 0.001
	done
done