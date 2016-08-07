require 'open-uri'
require 'nokogiri'

def get_runtimes_from_imdb_page(url)
  doc = Nokogiri::HTML open(url)
  runtime_strings =
    doc.xpath('//*[contains(@class,\'txt-block\')]/time').map(&:text)

  # runtime strings are of the form 'x min'
  runtime_strings.map { |r| r.split.first.to_i }
end
