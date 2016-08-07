require 'json'
require 'rest-client'
require 'ruby-progressbar'
require 'vcr'

require './movie_page_scraper.rb'
require './movie.rb'
require './vcr_config'

# Calculates statistics on Edgar Wright's 1000 favorite movies on mubi.com
class Mubi
  def formatted_runtime
    seconds = total_runtime * 60
    # Extract days of the year to strip 0 padding
    days = Time.at(seconds).utc.strftime('%j').to_i

    Time.at(seconds).utc.strftime("#{days} days, %H hours, and %M minutes.")
  end

  # Attribute methods

  # rubocop:disable MethodLength
  def movie_list_json
    @movie_list_json ||= VCR.use_cassette 'mubi_list_films' do
      # Each page has 48 movies, ceiling of 1000 / 48 is 21.
      pages = 21

      progressbar = ProgressBar.create \
        title: 'Fetching Movie List ',
        total: pages

      json = (1..pages).map do |page|
        progressbar.increment

        JSON.parse RestClient.get \
          'https://mubi.com/services/api/lists/108835/list_films',
          params: { page: page }
      end

      progressbar.finish

      # There shouldn't be any duplicates, but just in case
      json.flatten.uniq
    end
  end

  # Constructs a Movie object for each one in Edgar's top 1000
  # rubocop:disable AbcSize
  def movie_list
    @movie_list ||= VCR.use_cassette 'mubi_list_film_pages' do
      progressbar = ProgressBar.create \
        title: 'Scraping Movie Pages',
        total: movie_list_json.length

      movie_list = movie_list_json.each.map do |m|
        progressbar.increment

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

      progressbar.finish

      movie_list
    end
  end

  # In minutes
  def total_runtime
    @total_runtime ||= movie_list.map(&:runtime).reduce(0, :+)
  end
end
