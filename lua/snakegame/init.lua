local M = {}

local GAME_CONFIG = {
  fps = 60.0,
  width = 30,
  height = 20,
  move_interval = 4,
}

local DISPLAY_CONFIG = {
  cell_width = 2,
  snake_char = "██",
  food_char = "██",
  empty_char = "  ",
}

local DIRECTIONS = {
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
}

local OPPOSITE_DIRECTIONS = {
  up = "down",
  down = "up",
  left = "right",
  right = "left",
}

local game_state = {
  snake = nil,
  food = nil,
  is_running = false,
  game_over = false,
  frame_count = 0,
  win = nil,
  buf = nil,
}

local function create_snake()
  local center_x = math.floor(GAME_CONFIG.width / 2)
  local center_y = math.floor(GAME_CONFIG.height / 2)

  local SNAKE_STARTER_LENGTH = 10

  local snake_body = {}
  for i = 1, SNAKE_STARTER_LENGTH do
    table.insert(snake_body, { x = center_x, y = center_y + i })
  end

  return {
    body = snake_body,
    direction = "up",
  }
end

local function generate_random_food_position()
  return {
    x = math.random(1, GAME_CONFIG.width),
    y = math.random(1, GAME_CONFIG.height),
  }
end

local function is_position_occupied_by_snake(x, y)
  for _, segment in ipairs(game_state.snake.body) do
    if segment.x == x and segment.y == y then
      return true
    end
  end
  return false
end

local function spawn_food()
  repeat
    game_state.food = generate_random_food_position()
  until not is_position_occupied_by_snake(game_state.food.x, game_state.food.y)
end

local function reset_game()
  game_state.snake = create_snake()
  spawn_food()
  game_state.frame_count = 0
  game_state.is_running = false
  game_state.game_over = false
end

local function wrap_coordinate(coord, max)
  if coord < 1 then
    return max
  end
  if coord > max then
    return 1
  end
  return coord
end

local function check_self_collision(new_head)
  for _, segment in ipairs(game_state.snake.body) do
    if segment.x == new_head.x and segment.y == new_head.y then
      return true
    end
  end
  return false
end

local function move_snake()
  local direction_vector = DIRECTIONS[game_state.snake.direction]
  if not direction_vector then
    return
  end

  local head = game_state.snake.body[1]
  local new_head = {
    x = wrap_coordinate(head.x + direction_vector.x, GAME_CONFIG.width),
    y = wrap_coordinate(head.y + direction_vector.y, GAME_CONFIG.height),
  }

  if check_self_collision(new_head) then
    game_state.is_running = false
    game_state.game_over = true
    return
  end

  table.insert(game_state.snake.body, 1, new_head)

  local ate_food = new_head.x == game_state.food.x and new_head.y == game_state.food.y
  if ate_food then
    spawn_food()
  else
    table.remove(game_state.snake.body)
  end
end

local function change_direction(new_direction)
  if not DIRECTIONS[new_direction] then
    return
  end

  if game_state.snake.direction == OPPOSITE_DIRECTIONS[new_direction] then
    return
  end

  game_state.snake.direction = new_direction
end

local function create_empty_screen()
  local screen = {}
  for y = 1, GAME_CONFIG.height do
    screen[y] = {}
    for x = 1, GAME_CONFIG.width do
      screen[y][x] = DISPLAY_CONFIG.empty_char
    end
  end
  return screen
end

local function render_snake_on_screen(screen)
  for _, segment in ipairs(game_state.snake.body) do
    screen[segment.y][segment.x] = DISPLAY_CONFIG.snake_char
  end
end

local function render_food_on_screen(screen)
  screen[game_state.food.y][game_state.food.x] = DISPLAY_CONFIG.food_char
end

local function render_game_over_text(screen)
  local mid_x = math.ceil(GAME_CONFIG.width / 2)
  local mid_y = math.ceil(GAME_CONFIG.height / 2)

  local title_text = "GAME OVER"
  local subtitle_text = "Press R to restart"

  local title_start_x = math.ceil(mid_x - (#title_text / 2))
  local subtitle_start_x = math.ceil(mid_x - (#subtitle_text / 2))

  local TEXT_OFFSET = 1

  for i = 0, #title_text do
    local char_index = i + 1
    screen[mid_y - TEXT_OFFSET][title_start_x + i] = " " .. title_text:sub(char_index, char_index)
  end

  for i = 0, #subtitle_text do
    local char_index = i + 1
    screen[mid_y + TEXT_OFFSET][subtitle_start_x + i] = " " .. subtitle_text:sub(char_index, char_index)
  end
end

local function render_game()
  local screen = create_empty_screen()
  render_snake_on_screen(screen)
  render_food_on_screen(screen)
  return screen
end

local function render()
  if not game_state.win or not game_state.buf then
    return
  end

  local screen = render_game()

  if game_state.game_over then
    render_game_over_text(screen)
  end

  local lines = {}
  for y = 1, GAME_CONFIG.height do
    lines[y] = table.concat(screen[y])
  end

  vim.api.nvim_buf_set_lines(game_state.buf, 0, GAME_CONFIG.height, false, lines)
end

local function frame()
  if not game_state.win or not game_state.buf then
    return
  end

  game_state.frame_count = game_state.frame_count + 1

  if game_state.frame_count % GAME_CONFIG.move_interval == 0 and not game_state.game_over then
    move_snake()
  end

  render()
  vim.defer_fn(frame, 1000 / GAME_CONFIG.fps)
end

local function setup_keymap()
  local key_mappings = {
    q = function()
      vim.api.nvim_win_close(0, true)
      game_state.win = nil
    end,
    h = function()
      change_direction("left")
    end,
    j = function()
      change_direction("down")
    end,
    k = function()
      change_direction("up")
    end,
    l = function()
      change_direction("right")
    end,
    r = function()
      if game_state.game_over then
        reset_game()
        game_state.is_running = true
      end
    end,
  }

  for key, callback in pairs(key_mappings) do
    vim.api.nvim_buf_set_keymap(game_state.buf, "n", key, "", {
      noremap = true,
      silent = true,
      callback = callback,
    })
  end
end

local function start_game()
  if game_state.is_running then
    return
  end

  reset_game()
  game_state.is_running = true

  game_state.buf = vim.api.nvim_create_buf(false, true)
  local window_config = {
    relative = "editor",
    width = GAME_CONFIG.width * DISPLAY_CONFIG.cell_width,
    height = GAME_CONFIG.height,
    col = (vim.o.columns - GAME_CONFIG.width * DISPLAY_CONFIG.cell_width) / 2,
    row = (vim.o.lines - GAME_CONFIG.height) / 2,
    border = "single",
    style = "minimal",
  }

  game_state.win = vim.api.nvim_open_win(game_state.buf, true, window_config)

  if not game_state.win then
    vim.notify("Failed to open window", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_set_option_value("number", false, { win = game_state.win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = game_state.win })
  vim.api.nvim_set_option_value("list", false, { win = game_state.win })
  vim.api.nvim_set_option_value("cursorline", false, { win = game_state.win })
  vim.api.nvim_set_option_value("cursorcolumn", false, { win = game_state.win })
  vim.api.nvim_set_option_value("number", false, { win = game_state.win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = game_state.win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = game_state.win })

  setup_keymap()
  frame()
end

M.setup = function()
  vim.api.nvim_create_user_command("SnakeGame", start_game, {})
end

return M
