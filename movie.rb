# Encapsulates data about each movie in the list
class Movie
  attr_accessor :id,
                :title,
                :directors,
                :release_country,
                :release_year,
                :genres,
                :runtime,
                :synopsis,
                :rating

  def initialize(params)
    @id = params[:id]
    @title = params[:title]
    @directors = params[:directors]
    @release_country = params[:release_country]
    @release_year = params[:release_year]
    @genres = params[:genres]
    @runtime = params[:runtime]
    @synopsis = params[:synopsis]
    @rating = params[:rating]
  end
end
