# color functions
red() {
	tput setab 1; tput setaf 7
}
yellow() {
	tput setab 3; tput setaf 7
}
green() {
	tput setab 2; tput setaf 7
}
reset() {
	tput setab 0; tput setaf 7;
}

# box array dimensions
num_box_rows=3
num_box_cols=4

# box spacing
margin=2
padding=1

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
height_increment=$(($box_height + $padding))

# starting cursor position
start_position=$margin

# function to output the info
output() {
	# move cursor
	tput cup $cursor_row $cursor_col

	# output info
	echo $1

	# increment row
	cursor_row=$(($cursor_row + 1))
}

# function to draw a colored background
spaces=""
for c in `seq 0 $(($box_width - 1))`
do
	spaces+=" "
done
draw_background() {
	# iterate through rows
	for r in `seq 0 $(($box_height - 1))`; do
		# iterate through columns
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
	#if (( $(echo "$change > 0" | bc) )); then
	green
	#elif (( $(echo "$change < 0" | bc) )); then
	#	red
	#else
	#	yellow
	#fi

	# output colored background
	draw_background

	# output all info
	output "`echo $line`"
	output "`echo $status`"

	# reset background
	reset
}

clear
while true
do
	# reset coordinates
        current_row=$start_position
        current_col=$start_position

	cat mta.txt | tr "\n" "|" | grep -o "<subway>.*</subway>" | tr "|" "\n" > subways.txt
	cat subways.txt | grep "<line>" -A 2 | cut -d ">" -f2 | cut -d "<" -f1 | grep '\S' | grep -v "^--$" > lines_status.txt 
	i=1
	while [ $i -le `wc -l < lines_status.txt` ]
	do
		line=`awk -v i=$i 'NR==i' < lines_status.txt`
		status=`awk -v i=$((i + 1)) 'NR==i' < lines_status.txt`
		write_info

		current_col=$(($current_col + $width_increment))
        	if ! (($current_col + $box_width < $window_width)); 
		then 
			current_col=$start_position
	               	current_row=$(($current_row + $height_increment))
        	fi

		i=$((i + 2))
	done
	sleep 5
done
