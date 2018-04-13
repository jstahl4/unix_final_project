# James Stahl
#
# Displays a matrix of stocks from 'stock.txt' with updated information
# ---------------------------------------------------------------------

# stock api strings
api_url='https://api.iextrading.com/1.0/stock'
api_options='batch?types=quote&range=1m&last=10'
data_path='/tmp/.stocks.json'
stocks_filename='stocks.txt'

# color functions
red() {
	tput setab 1; tput setaf 7
}
yellow() {
	tput setab 2; tput setaf 7
}
green() {
	tput setab 3; tput setaf 7
}
reset() {
	tput sgr0
}

# box array dimensions
num_box_rows=6
num_box_cols=5

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
draw_background() {
	# iterate through rows
	for r in `seq 0 $(($box_height - 1))`; do
		# iterate through columns
		for c in `seq 0 $(($box_width - 1))`; do
			tput cup $(($cursor_row + $r)) $(($cursor_col + $c))
			printf " "
		done
	done
}

# function to write the info in the box
write_info() {
	# set cursor position
	cursor_row=$current_row
	cursor_col=$current_col

	# set background
	if (( $(echo "$change > 0" | bc) )); then
		green
	elif (( $(echo "$change < 0" | bc) )); then
		red
	else
		yellow
	fi

	# output colored background
	draw_background

	# output all info
	output $symbol
	output $companyName
	output $latestPrice
	output $change
	output $latestVolume

	# reset background
	reset
}

# main program loop, each iteration goes through 30 stocks
clear
while true
do
	# reset coordinates
	current_row=$start_position
	current_col=$start_position

	# loop to handle each stock
	for stock in `cat $stocks_filename`
	do
		# obtain stock data
		#url="$api_url/$stock/$api_options"
		url="https://api.iextrading.com/1.0/stock/$stock/batch?types=quote&range=1m&last=10"
		wget -qO- $url > $data_path

		# parse relevant info
		symbol=`jq .quote.symbol $data_path | sed -e 's/^"//' -e 's/"$//'`
		companyName=`jq .quote.companyName $data_path | sed -e 's/^"//' -e 's/"$//'`
		latestPrice=`jq .quote.latestPrice $data_path | sed -e 's/^"//' -e 's/"$//'`
		change=`jq .quote.change $data_path | sed -e 's/^"//' -e 's/"$//'`
		latestVolume=`jq .quote.latestVolume $data_path | sed -e 's/^"//' -e 's/"$//'`

		# draw box
		write_info

		# update coordinates
		current_col=$(($current_col + $width_increment))
		if ! (($current_col + $box_width < $window_width)); then
			current_col=$start_position
			current_row=$(($current_row + $height_increment))
		fi

	done
	sleep 1
done
