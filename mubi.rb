require 'rest-client'
require 'nokogiri'
require 'json'
require 'vcr'

require './vcr_config'

# Calculates statistics on Edgar Wright's 1000 favorite movies on mubi.com
class Mubi
  def calculate_total_runtime
    runtimes = movie_list.map { |m| runtime_for_movie m['film_id'] }

    puts format_runtime runtimes.reduce(0, :+)
  end

  def format_runtime(minutes)
    seconds = minutes * 60
    # Extract days of the year to strip 0 padding
    days = Time.at(seconds).utc.strftime('%j').to_i

    Time.at(seconds).utc.strftime("#{days} days, %H hours, and %M minutes.")
  end

  def runtime_for_movie(id)
    doc = movie_page_list[id]

    # The movie duration was not available via an API call like the movie list
    # However, it is conveniently the only text of this node
    doc.css('.film-show__film-meta').text.strip.to_i
  end

  def movie_list
    @movie_list ||= VCR.use_cassette 'mubi_list_films' do
      # Each page has 48 movies, ceiling of 1000 / 48 is 21.
      json = (1..21).map do |page|
        puts page

        response = RestClient.get 'https://mubi.com/services/api/lists/108835/list_films',
                                  params: { page: page }

        JSON.parse response
      end

      # There shouldn't be any duplicates, but just in case
      json.flatten.uniq
    end
  end

  def movie_page_list
    @movie_page_list ||= VCR.use_cassette 'mubi_list_film_pages' do
      page_list_array = movie_list.each_with_index.map do |movie, i|
        puts i + 1
        response = RestClient.get "https://mubi.com/films/#{movie['film_id']}"

        [movie['film_id'], Nokogiri::HTML(response)]
      end

      Hash[page_list_array]
    end
  end
end
