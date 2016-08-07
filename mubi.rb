require 'rest-client'
require 'nokogiri'
require 'json'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'vcr_cassettes'
  c.hook_into :webmock
end

def get_movie_list
  VCR.use_cassette('mubi_list_films') do
    # Each page has 48 movies, ceiling of 1000 / 48 is 21.
    json = (1..21).map do |page|
      response = RestClient.get 'https://mubi.com/services/api/lists/108835/list_films',
                                params: { page: page }

      JSON.parse response
    end

    # There shouldn't be any duplicates, but just in case
    json.flatten.uniq
  end
end

def get_runtime_for_movie(movie_id)
  doc = Nokogiri::HTML RestClient.get "https://mubi.com/films/#{movie_id}"

  # The movie duration was not available via an API call like the movie list
  # However, it is conveniently the only text of this node
  doc.css('.film-show__film-meta').text.strip.to_i
end

def calculate_total_runtime
  VCR.use_cassette('mubi_get_runtime') do
    movie_list = get_movie_list

    runtimes = movie_list.each_with_index.map do |movie|
      get_runtime_for_movie movie['film_id']
    end

    puts format_runtime runtimes.reduce(0, :+)
  end
end

def format_runtime(minutes)
  seconds = minutes * 60
  # Extract days of the year to strip 0 padding
  days = Time.at(seconds).utc.strftime('%j').to_i

  Time.at(seconds).utc.strftime("#{days} days, %H hours, and %M minutes.")
end
