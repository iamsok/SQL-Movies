require 'sinatra'
require 'pg'
require 'pry'

set :port, 5002

def db_connection
  begin
    connection = PG.connect(dbname: 'movies')
    yield(connection)
  ensure
    connection.close
  end
end

def find_all_actors
  sql = "SELECT name, id FROM actors"
  actors = db_connection do |db|
    db.exec(sql)
  end
  actors.to_a
end

def find_actor_by_id(actor_id)
  sql = "SELECT name FROM actors WHERE id = $1"
  actor = db_connection do |db|
    db.exec_params(sql, [actor_id])
  end
  actor.to_a.first
end

def find_movie_by_id(movie_id)
  sql = "SELECT title FROM movies WHERE id = $1"
  movie = db_connection do |db|
    db.exec_params(sql, [movie_id])
  end
  movie.to_a.first
end

def movies_starred_by_actor_id(actor_id)
  sql = %{
  SELECT movies.title, cast_members.character
  FROM movies
  JOIN cast_members ON movies.id = cast_members.movie_id
  WHERE cast_members.actor_id = $1;
  }
  roles = db_connection do |db|
    db.exec_params(sql, [actor_id])
  end
  roles.to_a
end

def all_movies_sorted_title
  sql = %{
    SELECT movies.id, movies.title, movies.year, movies.rating, genres.name AS genre, studios.name
    FROM movies
    JOIN genres ON movies.genre_id = genres.id
    JOIN studios ON movies.studio_id = studios.id
    ORDER BY movies.title
  }
  movies = db_connection do |db|
    db.exec(sql)
  end
  movies.to_a
end

def something(movie_id)
  sql = %{
    SELECT movies.id, movies.title, movies.year, movies.rating, genres.name AS genre, studios.name AS studio, actors.name AS actor, cast_members.character
    FROM movies
    JOIN genres ON movies.genre_id = genres.id
    JOIN studios ON movies.studio_id = studios.id
    JOIN cast_members ON movies.id = cast_members.movie_id
    JOIN actors ON cast_members.actor_id = actors.id
    WHERE movies.id = $1
  }
  lots_of_stuff = db_connection do |db|
    db.exec_params(sql,[movie_id])
  end
  lots_of_stuff.to_a
end

def find_movie_id_by_title(title)
  sql = %{
    SELECT movies.id FROM movies WHERE movies.title = $1
  }
  movie_id = db_connection do |db|
    db.exec_params(sql,[title])
  end
  movie_id.to_a
end
helpers do
  def find_actor_id_by_name(name)
    sql = %{
      SELECT id FROM actors WHERE actors.name = $1
    }
    actor_id = db_connection do |db|
      db.exec_params(sql,[name])
    end
    actor_id.to_a.first
  end
end
############################################################
####                    Routes                          ####
############################################################
get '/' do
  redirect 'actors'
end

get '/actors' do
  @actors = find_all_actors.sort_by {|actor| actor["name"]}
  erb :'actors/index'
end

get '/actors/:id' do
  @actor = find_actor_by_id(params[:id])
  @roles = movies_starred_by_actor_id(params[:id])
  @title = @roles[0]["title"]

  @movie_id = find_movie_id_by_title(@title)
  erb :'actors/roles'
end

get '/movies' do
  @all_movies = all_movies_sorted_title
  erb :'movies/index'
end

get '/movies/:id' do
  @individual_movie = find_movie_by_id(params[:id])
  @movie_info = something(params[:id])
  erb :'movies/show'
end
