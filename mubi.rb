require 'json'
require 'nokogiri'
require 'rest-client'
require 'vcr'

require './movie_page_scraper.rb'
require './movie.rb'
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
        s = MoviePageScraper.new m['film_id']

        Movie.new \
          id: m['film_id'],
          title: m['film']['title'],
          directors: m['film']['directors'].map { |d| d['name'] },
          release_country: s.release_country,
          release_year: m['film']['year'],
          genres: s.genres,
          runtime: s.runtime,
          synopsis: s.synopsis,
          rating: s.rating
      end
    end
  end
end
