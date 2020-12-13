# frozen_string_literal: true

require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

helpers do
  def todos_count(list)
    list[:todos].length
  end

  def list_complete?(list)
    todos_count(list).positive? && todos_remaining_count(list).zero?
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].reject { |todo| todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end#

  def sort_todos(todos)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] } #

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect  
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(list_name)
  if !(1..100).cover?(list_name.size)
    'The list name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == list_name }
    'List name must be unique.'
  end
end

def error_for_todo(list_id, todo_name)
  if !(1..100).cover?(todo_name.size)
    'The todo name must be between 1 and 100 characters.'
  elsif @storage.find_todos_for_list(list_id).any? { |todo| todo[:name] == todo_name }
    'Todo name must be unique.'
  end
end

# Check if list is valid and either return valid list or redirect
def load_list(id)
  list = @storage.find_list(id)
  
  return list if list

  session[:error] = "The specified list was not found."
  redirect '/lists'
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

get '/' do
  redirect '/lists'
end

# View all the lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)


    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# view a todo list
get '/lists/:id' do
  id = params[:id].to_i
  @list = load_list(id)

  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# update an existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(id, list_name)
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i
  
  @storage.delete_list(id)

  session[:success] = 'The list has been deleted.'

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  error = error_for_todo(@list_id, text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
    session[:success] = 'The todo has been added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list item
post '/lists/:list_id/todos/:id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:id].to_i 

  @storage.delete_todo_from_list(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else 
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update status of todo

post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:id].to_i
  is_completed = params[:completed] == 'true'

  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Update all todo items
post '/lists/:list_id/check_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_complete(@list_id)

  session[:success] = 'All todos have been updated.'
  redirect "/lists/#{@list_id}"
end

