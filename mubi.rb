require 'rest-client'
require 'nokogiri'
require 'json'

def get_movie_list
 json = (1..21).to_a.map do |page|
   puts page
   JSON.parse RestClient.get 'https://mubi.com/services/api/lists/108835/list_films', params: { page: page }
 end

 json.flatten.uniq
end
