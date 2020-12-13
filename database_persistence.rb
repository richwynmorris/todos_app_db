require "pg"

class DatabasePersistence

  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, id)

    tuple = result.first
    todos = find_todos_for_list(tuple["id"])

    {id: tuple["id"], name: tuple["name"], todos: todos}
  end

  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)

    result.map do |tuple|
      todos = find_todos_for_list(tuple["id"])
      {id: tuple["id"].to_i, name: tuple["name"], todos: todos}
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    result = query(sql, list_name)

    # id = next_element_id(@session[:lists])
    # @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    query("DELETE FROM todo WHERE list_id = $1", list_id)
    query("DELETE FROM lists WHERE id=$1", list_id)

    # @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(id, list_name)
    sql = "UPDATE lists SET name=$1 WHERE id=$2"
    query(sql, list_name, id)

    # list = find_list(id)
    # list[:name] = list_name
  end

  def create_new_todo(list_id, text)
    sql = "INSERT INTO todo (list_id, name) VALUES ($1, $2);"
    query(sql, list_id, text)

    # list = find_list(list_id)
    # id = next_element_id(list[:todos])
    # list[:todos] << { id: id, name: text, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todo WHERE id=$1 AND list_id=$2;"
    result = query(sql, todo_id, list_id)
    # list = find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, status)
    sql = "UPDATE todo SET completed=$1 WHERE list_id=$2 AND id=$3"
    query(sql, status, list_id, todo_id)

    # list = find_list(list_id)
    # todo = list[:todos].find { |t| t[:id] 
    # list = find_list(list_id)== todo_id }
    # todo[:completed] = status
  end

  def mark_all_todos_complete(list_id)
    sql = "UPDATE todo SET completed=$1 WHERE list_id=$2;"
    query(sql, true, list_id )
    # list = find_list(list_id)

    # list[:todos].each do |todo|
    #   todo[:completed] = true
    # end
  end

  def find_todos_for_list(tuple_id)
    todo_sql = "SELECT * FROM todo WHERE list_id = $1"
    todo_result = query(todo_sql, tuple_id)

    todo_result.map do |todo_tuple|
      {id: todo_tuple["id"].to_i, name: todo_tuple["name"], completed: todo_tuple["completed"] == 't'}
    end
  end
end 