require 'json'
require 'rest-client'
require 'ruby-progressbar'
require 'vcr'

require './movie_page_scraper.rb'
require './movie.rb'
require './vcr_config'

# Calculates statistics on Edgar Wright's 1000 favorite movies on mubi.com
class Mubi
  def initialize
    movie_list_json
    movie_list

    generate_histogram_methods
  end

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

  def synopsis_word_histogram
    @synopsis_word_histogram ||= begin
      hist = Hash.new 0

      # /[[:word:]]+/ matches any unicode word, so the regex below matches any
      # word with an apostrophe at the end, and potentially more text following
      regex = /[[:word:]]+’*[[:word:]]*/
      synopsis_words = movie_list.map { |m| m.synopsis.scan(regex) }
                                 .flatten
                                 .map(&:downcase)

      synopsis_words.each { |word| hist[word] += 1 }
      Hash[hist.sort_by { |_, v| v }.reverse]
    end
  end

  # In minutes
  def total_runtime
    @total_runtime ||= movie_list.map(&:runtime).reduce(0, :+)
  end

  private

  # Make methods for making histograms of the appropriate attributes
  def generate_histogram_methods
    hist_attributes = %w(
      directors
      release_year
      release_country
      genres
      runtime
      rating
    )

    hist_attributes.each do |a|
      method_name = "#{unpluralize a}_histogram"
      iv_name = "@#{method_name}"

      define_singleton_method method_name do
        instance_variable_set iv_name, memoize(iv_name, a)
      end
    end
  end

  # Avoids recalculation if the instance variable is already defined
  def memoize(iv_name, a)
    if instance_variable_defined? iv_name
      instance_variable_get iv_name
    else
      hist = Hash.new 0
      # Array of attributes corresponding to the method name
      array = movie_list.map { |m| m.send a }

      array.flatten.each { |e| hist[e] += 1 }
      Hash[hist.sort_by { |_, v| v }.reverse]
    end
  end

  def unpluralize(word)
    return word.chop if word.end_with? 's'
    word
  end
end
