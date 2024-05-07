require 'watir'
require 'csv'

INDEX_PAGE = 'https://www.ceilingfansdirect.com.au/category/exhaust-fans-170'.freeze
CSV_PATH = "tmp/fans_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv".freeze

CSS_SELECTORS = {
  name: 'h1',
  price: '.single-product-summary__total-price',
  specifications_table_row_header: '.single-product-specs__row-header',
  specifications_table_row_value: '.single-product-specs__row-value',
  close_button: 'button.close',
  product_links: '.product-card > a',
}

def extract_fields(browser, url, csv_writer)
  browser.goto(url)

  name = browser.element(css: CSS_SELECTORS[:name]).text || 'N/A' rescue 'N/A'
  price = browser.element(css: CSS_SELECTORS[:price]).text.gsub(/[^\d.]/, '').to_f.round.to_s || 'N/A' rescue 'N/A'

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
  headers = browser.elements(css: CSS_SELECTORS[:specifications_table_row_header]).map(&:innertext)

  header_candidates.each do |header_text|
    header_index = headers.index(header_text)
    return header_index unless header_index.nil?
  end

  # fallback to a large index value
  -1
end

# Submethod to extract the numeric value from a table cell
def extract_numeric_value_from_cell(browser, cell_index)
  numeric_value = browser.elements(css: CSS_SELECTORS[:specifications_table_row_value])[cell_index].innertext
  numeric_value = numeric_value[/\d+(\.\d+)?/] || 'N/A'
  numeric_value.to_f.round.to_s unless numeric_value == 'N/A'
end

def extract_to_csv(browser, anchor_nodes)
  # Create and open the CSV file for writing
  CSV.open(CSV_PATH, 'ab') do |csv|
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
browser.goto(INDEX_PAGE)

Watir::Wait.until {
  browser.element(css: '.next-button').visible? &&
  browser.elements(css: '.product-card a').length > 1
}

puts "Closing modal (if any)..."
browser.wait_until(timeout: 10) { |b| b.element(css: CSS_SELECTORS[:close_button]) }
if browser.element(css: CSS_SELECTORS[:close_button]).exists?
  browser.element(css: CSS_SELECTORS[:close_button]).click
end

all_product_links = []
urls = []
while(true) do
  urls << browser.url
  # Wait until the products are present on the page before proceeding
  browser.wait_until(timeout: 100) { |b| b.elements(css: '.product-card > a') }

  puts "Getting nodes..."
  product_links = browser.elements(css: CSS_SELECTORS[:product_links]).map { |anchor| anchor.attribute_value('href') }
  break if product_links.empty?
  all_product_links << product_links
  pp urls
  pp product_links

  begin
    browser.wait_until(timeout: 6) { |b| b.element(css: '.next-button').exists? }
    d = browser.element(css: '.next-button')

    puts "d found: #{d.exists?}"
    d.click

    old_first_product = browser.elements(css: '.product-card > a')[0]
    Watir::Wait.until {
      browser.element(css: '.next-button').visible? && 
      browser.elements(css: '.product-card > a')[0] != old_first_product
    }

    true
  rescue Watir::Wait::TimeoutError, Watir::Exception::UnknownObjectException, Selenium::WebDriver::Error::ElementClickInterceptedError
    # If the element is not found or the wait times out, we assume there are no more pages.
    puts 'No more pages to load.'
    break
  end
end

extract_to_csv(browser, all_product_links.flatten.uniq)

puts "Done!"
# browser.close
