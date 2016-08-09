require 'nokogiri'
require 'rest-client'

# Scrapes a movie's mubi page for information not provided by the API
class MoviePageScraper
  CSS_SELECTORS = {
    release_country: '.film-show__country-year',
    genres: '.film-show__genres',
    runtime: '.film-show__film-meta',
    synopsis: '.film-show__descriptions__synopsis',
    rating: '.film-show__average-rating-overall'
  }.freeze

  def initialize(id)
    @doc = Nokogiri::HTML RestClient.get "https://mubi.com/films/#{id}"
  end

  def release_country
    @release_country ||=
      # The line is in the form country, year
      @doc.css(CSS_SELECTORS[:release_country]).text.strip.split(',').first
  end

  def genres
    @genres ||= begin
      text = @doc.css(CSS_SELECTORS[:genres]).text.strip

      # Genres are comma separated
      text.split(',').map(&:strip)
    end
  end

  # In minutes
  def runtime
    @runtime ||= @doc.css(CSS_SELECTORS[:runtime]).text.strip.to_i
  end

  def synopsis
    @synopsis ||=
      # Synopsis is in the form Synopsis\n<synopsis copy>. We want the copy.
      @doc.css(CSS_SELECTORS[:synopsis]).text.strip.split("\n")[1]
  end

  def rating
    @rating ||= @doc.css(CSS_SELECTORS[:rating]).text.strip.to_f
  end
end
