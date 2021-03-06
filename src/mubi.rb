require 'json'
require 'pathname'
require 'rest-client'
require 'ruby-progressbar'
require 'vcr'

require './movie_page_scraper.rb'
require './movie.rb'
require './vcr_config'

# Calculates statistics on Edgar Wright's 1000 favorite movies on mubi.com
# rubocop:disable ClassLength
class Mubi
  def initialize
    movie_list_json
    movie_list

    generate_histogram_methods
    generate_histogram_write_methods
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
      # Each page has 48 movies, 1000 movies total
      pages = (1000 / 48.0).ceil

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

  def write_all_histograms
    HIST_ATTRIBUTES.each do |a|
      send "#{unpluralize a}_histogram_write"
    end

    nil
  end

  private

  HIST_ATTRIBUTES = %w(
    directors
    release_year
    release_country
    genres
    runtime
    synopsis_words
    rating
  ).freeze

  # Make methods for making histograms of the appropriate Movie attributes
  def generate_histogram_methods
    HIST_ATTRIBUTES.each do |a|
      method_name = "#{unpluralize a}_histogram"
      instance_variable_name = "@#{method_name}"

      define_singleton_method method_name do
        memoized_result = memoize instance_variable_name do
          hist = Hash.new 0
          # Array of attributes corresponding to the method name
          array = movie_list.map { |m| m.send a }

          array.flatten.each { |e| hist[e] += 1 }
          Hash[hist.sort_by { |_, v| v }.reverse]
        end

        instance_variable_set instance_variable_name, memoized_result
      end
    end
  end

  def generate_histogram_write_methods
    project_root = Pathname.pwd.parent
    data_dir = project_root.join('stats').join('data')
    Dir.mkdir data_dir unless Dir.exist? data_dir

    HIST_ATTRIBUTES.each do |a|
      unpluralized_attribute = unpluralize a
      method_base = "#{unpluralized_attribute}_histogram"

      define_singleton_method "#{method_base}_write" do
        File.open data_dir.join(unpluralized_attribute), 'w' do |file|
          hist = send method_base

          file.write unpluralized_attribute
          file.write ' count'
          file.write "\n"

          hist.each_pair do |k, v|
            write_stat_line file, k, v
          end
        end

        nil
      end
    end
  end

  # Avoids recalculation if the instance variable is already defined
  def memoize(instance_variable_name)
    if instance_variable_defined? instance_variable_name
      instance_variable_get instance_variable_name
    else
      yield
    end
  end

  def unpluralize(word)
    return word.chop if word.end_with? 's'
    word
  end

  def write_stat_line(file, stat, value)
    file.write "\"#{stat}\""
    file.write ' '
    file.write value
    file.write "\n"
  end
end
