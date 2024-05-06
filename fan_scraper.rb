require 'watir'
require 'csv'

def extract_fields(browser, url, csv_writer)
  browser.goto(url)

  name = browser.element(css: 'h1').text || 'N/A' rescue 'N/A'
  price = browser.element(css: '.li-product-banner__price').text.gsub(/[^\d.]/, '').to_f.round.to_s || 'N/A' rescue 'N/A'

  # Extract decibel_level as a numeric value from the table cell matching the table header "Air Extraction (m3/hr)"
  air_rate_headers = ['Air Extraction (m3/hr)', 'Air Extraction Rate', 'Air Extraction', 'Air Extraction (m³/h)', 'Air Extraction (m³H)', 'Air Extraction (m3H)', 'Air Extraction (m3/h)', 'Air Extraction (m³/hr)']
  air_extraction_rate_index = find_table_header_index(browser, air_rate_headers)
  air_extraction_rate = extract_numeric_value_from_cell(browser, air_extraction_rate_index) #  || 'N/A' rescue 'N/A'

  # Extract decibel_level as a numeric value from the table cell matching the table header "Decibel Rating"
  decibel_headers = ['Decibel Rating', 'Decibel Level', 'Decibel']
  decibel_index = find_table_header_index(browser, decibel_headers)
  decibel_level = extract_numeric_value_from_cell(browser, decibel_index) #  || 'N/A' rescue 'N/A'

  puts "Name: #{name}"
  puts "Price: #{price}"
  puts "Air Extraction Rate: #{air_extraction_rate}"
  puts "Decibel Level: #{decibel_level}"
  puts "URL: #{url}"
  puts '----------------------'

  csv_writer << [name, price, air_extraction_rate, decibel_level, url]
end

# Submethod to find the index of the specified table header from a list of possible headers
def find_table_header_index(browser, header_candidates)
  headers = browser.elements(css: 'table.li-tab__table th').map(&:innertext)

  header_candidates.each do |header_text|
    header_index = headers.index(header_text)
    return header_index unless header_index.nil?
  end

  # fallback to a large index value
  -1
end

# Submethod to extract the numeric value from a table cell
def extract_numeric_value_from_cell(browser, cell_index)
  numeric_value = browser.elements(css: "table.li-tab__table td")[cell_index].innertext
  numeric_value = numeric_value[/\d+(\.\d+)?/] || 'N/A'
  numeric_value.to_f.round.to_s unless numeric_value == 'N/A'
end

# Function to load additional items on the page
def load_more_items(browser)
  browser.wait_until(timeout: 6) { |b| b.div(css: '.li-button[data-testid]').exists? }
  d = browser.div(css: '.li-button[data-testid]')
  puts "d found: #{d.exists?}"
  d.click
  true
rescue Watir::Wait::TimeoutError, Watir::Exception::UnknownObjectException
  # If the element is not found or the wait times out, we assume there are no more items to load.
  puts 'No more items to load.'
  false
end

def extract_to_csv(browser, anchor_nodes)
  # Create and open the CSV file for writing
  CSV.open("fans_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv", 'wb') do |csv|
    begin
      # Write the CSV header row
      csv << ['Name', 'Price ($)', 'Air Extraction Rate (m3h)', 'Decibel Level (dBA)', 'URL']

      anchor_nodes.each do |anchor|
        url = anchor
        extract_fields(browser, url, csv)
      end
    ensure
      csv.close if csv
    end
  end
end

puts "Starting..."
browser = Watir::Browser.new(:firefox)
browser.goto('https://www.ceilingfansdirect.com.au/c/exhaust-fans-170')

# Get all the anchor nodes within div.li-product__list-item
puts "Closing modal..."
browser.wait_until(timeout: 10) { |b| b.button(class: 'close') }
browser.button(class: 'close').click

puts "Loading additional items..."
while load_more_items(browser); end

# Wait until the elements are present on the page before proceeding
browser.wait_until { |b| b.divs(class: 'li-product__list-item') }

puts "Getting nodes..."
anchor_nodes = browser.divs(class: 'li-product__list-item').map { |div| div.link.attribute_value('href') }
pp anchor_nodes

extract_to_csv(browser, anchor_nodes)

puts "Done!"
# browser.close