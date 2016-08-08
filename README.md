# Edgar Wright's Top 1000 movies

In a similar vein of my [imdb-scraper](https://github.com/mpace965/imdb-scraper)
repo, I recently saw Edgar Wright's list of his
[top 1000 favorite movies](https://mubi.com/lists/edgar-wrights-favorite-movies),
so I decided to try out a similar project. However, this time, I wanted it to be
a bit more robust.

## Installing

Prior to installing, you should have Ruby 2.3.1 downloaded on your machine. If
you do not, [rvm](https://rvm.io/) provides an easy way of doing so. Once you
have Ruby 2.3.1 installed, just clone this repo and then run

1. `gem install bundler`, if you haven't
1. `bundle install`

## Using

The easiest way to interact with the data is to fire up an `irb` session:

```
$ irb
2.3.1 :001 > require './mubi'
2.3.1 :002 > m = Mubi.new
```

You will see some loading, most of this is Nokogiri parsing documents. Some of
the information about the movies was exposed over Mubi's API, but other data
had to be scraped from the movie's page.

These network requests are cached with VCR. Most of the data should be pretty
static, save for the rating data. If you want to re-record the cassettes,
just delete the files in the `vcr_cassettes` directory.

### Methods

There are several methods at your disposal to expose the data.

- `Mubi#movie_list_json` exposes an array of raw JSON responses from Mubi's API
of all 1000 movies
- `Mubi#movie_list` exposes an array of `Movie` objects, which are populated with
information from the JSON, as well as the scraped webpage. Look at
[movie.rb](movie.rb) for all of the fields.
- `Mubi#total_runtime` and `Mubi#formatted_runtime` - `total_runtime` will
return the total runtime of the list in minutes, and `formatted_runtime` will
return the total runtime of the list in days, hours, and minutes.

#### `_histogram` Methods

There are several data sets for which it made sense to make a histogram. The
histograms are sorted from highest occurring key to lowest.

- `Mubi#director_histogram`
- `Mubi#genre_histogram`
- `Mubi#rating_histogram`
- `Mubi#release_country_histogram`
- `Mubi#release_year_histogram`
- `Mubi#runtime_histogram`
- `Mubi#synopsis_word_histogram`
  - Splits each synopsis into its individual words, and makes a histogram of all
  of these words.


## What's Next?

In the future I'd like to add some data visualization, as well as a site-layer
abstraction, so that this scraper can be used with sites like IMDb.
