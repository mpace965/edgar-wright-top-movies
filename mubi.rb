require 'json'
require 'nokogiri'
require 'rest-client'
require 'vcr'

require './movie.rb'
require './scraper.rb'
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

  # Scrapes the film's mubi page for information not available from the JSON
  def other_info_for_movie(id)
    doc = Nokogiri::HTML RestClient.get "https://mubi.com/films/#{id}"

    {
      release_country: doc.css('.film-show__country-year').text.strip.split.first.chop,
      runtime: doc.css('.film-show__film-meta').text.strip.to_i
    }
  end

  def movie_list_json
    @movie_list_json ||= VCR.use_cassette 'mubi_list_films' do
      # Each page has 48 movies, ceiling of 1000 / 48 is 21.
      json = (1..21).map do |page|
        puts page

        JSON.parse RestClient.get(
          'https://mubi.com/services/api/lists/108835/list_films',
          params: { page: page }
        )
      end

      # There shouldn't be any duplicates, but just in case
      json.flatten.uniq
    end
  end

  def movie_list
    @movie_list ||= VCR.use_cassette 'mubi_list_film_pages' do
      movie_list_json.each_with_index.map do |m, i|
        puts i + 1
        other_info = other_info_for_movie m['film_id']

        movie = Movie.new \
          id: m['film_id'],
          title: m['film']['title'],
          directors: m['film']['directors'],
          release_year: m['film']['year']

        movie
      end
    end
  end
end

m = Mubi.new
m.movie_list
