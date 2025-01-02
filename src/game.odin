//!/usr/bin/env odin build game.odin -file
/* game.odin 0.1.2
 * Beta version of a simple 2d game
====================================================

Label statements:
    //@CLEARLINES    /*To clear the lines
                        and the columns full.*/
    //@COLLISIONCHECK/**/

======================= TASKS =======================
TODO:
======================= -DONE =======================
################# TODO: Add states ##################
################# TODO: Publish onto github #########
################# TODO: Preview #####################
################# TODO: Colors ######################
################# TODO: Pieces ######################
*/


package example_gui
import "core:os"
import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"


Grid_Square :: enum u8 {
    Empty,
    Full,
    Block,
    Fading
}



Colors :: struct {
    Empty, Full, Fading: rl.Color 
}


State :: struct {
    game_over: bool,
    pause: bool,
    to_delete: bool,
    preview_activated: bool,

    grid:        [GRID_HORZSIZE][GRID_VERTSIZE+1]Grid_Square,
    colors:      [GRID_HORZSIZE][GRID_VERTSIZE+1]rl.Color,
    palette:     []rl.Color,

    pieces_buffer:[3][][]Grid_Square,
    colors_buffer:[3]rl.Color,


    mouse_position : rl.Vector2,
}

GRID_HORZSIZE :: 10
GRID_VERTSIZE :: 10

/* basic Configuration */
Configuration :: struct {
    SQUARE_SIZE: i32,
    SCREEN_WIDTH: i32,
    SCREEN_HEIGHT: i32,
    color_configuration: Colors,
    pieces: [][][]Grid_Square
}


main :: proc() {
    //initialization
    rl.InitWindow(400,500, "Game")
    defer rl.CloseWindow()

    state: State
    config: Configuration

    init_game(&state,&config)


    //fmt.printf("color_buffer = %v\n",state.colors_buffer);
    //main loop
    fmt.printf("---- printing configuration -----\n");
    
    config.pieces = {
        {{.Block,.Block,.Block},{.Block,.Block,.Block}},
        {{.Block,.Block},{.Block,.Block}},
        {{.Block,.Block,.Block},{.Empty,.Block}},
        {{.Empty,.Block},{.Block,.Block,.Block}},
        {{.Block},{.Block,.Block},{.Block}},
        {{.Empty,.Block},{.Block}},
        {{.Empty,.Block},{.Block}}
    };
    fmt.printf("configuration: %v, %v, %v\n",
        []i32{config.SQUARE_SIZE,
            config.SCREEN_WIDTH,
            config.SCREEN_HEIGHT},
        config.color_configuration,
        config.pieces)
    fmt.printf("---- done printing -----\n");
    rl.SetTargetFPS(60) 
    for !rl.WindowShouldClose(){
        update_game(&state,&config)
        draw_game(&state,&config)
    }
}

init_game :: proc(state: ^State, config: ^Configuration) {
    /*Note: this only takes care of a few things, 
      you have to configure your pieces yourself*/
    state^.to_delete = false

    
    palette := []rl.Color {
        rl.YELLOW,
        rl.RED,
        rl.GREEN,
        rl.BLUE,
        rl.PURPLE,
        rl.BROWN
    }

    state^.pieces_buffer = {
        rand.choice(config^.pieces),
        rand.choice(config^.pieces),
        rand.choice(config^.pieces)
    }
    state^.colors_buffer = {
        rand.choice(state^.palette),
        rand.choice(state^.palette),
        rand.choice(state^.palette)
    }
    state^.palette = palette
    state^.preview_activated = true;

    fmt.printf("palette:%v\n",state^.palette)
    fmt.printf("preview_activated:%d\n",state^.preview_activated)
    state^.grid = {}

    for j in 0..<GRID_VERTSIZE {
        for i in 0..<GRID_HORZSIZE {
            switch {
            case j == GRID_VERTSIZE - 1,
                 i == GRID_HORZSIZE-1,
                 i == 0,
                 j == 0:
                state^.grid[i][j] = .Full
            }
        }
    }

    config^.SQUARE_SIZE = 30
    config^.SCREEN_WIDTH = 400
    config^.SCREEN_HEIGHT = 500


    config^.color_configuration = Colors {
        Empty=rl.BLACK,
        Full=rl.GRAY,
        Fading = rl.RED
    }

    

}


update_game :: proc(state: ^State, config: ^Configuration){
    if state^.game_over && rl.IsKeyPressed(.ENTER){
        init_game(state,config)
        state^.game_over = false
        return
    } else if rl.IsKeyPressed(.P) {
        state^.pause = !state^.pause
    }

    if state^.pause {
        return
    }

    state^.mouse_position = rl.GetMousePosition()
    if state^.to_delete {
        //@CLEARLINES
        lines, cols := blocks_to_clear(state^.grid)
        defer delete(lines)
        defer delete(cols)


        for line in lines {
            for i in 1..<GRID_HORZSIZE-1{
                state^.grid[i][line] = .Empty
            }
        }

        for col in cols {
            for j in 1..<GRID_VERTSIZE-1{
                state^.grid[col][j] = .Empty
            }
        }

        state^.to_delete = false
    }
}
/*check_gameover :: proc(state: State) -> bool{
    if(state.game_over){
        return true
    }

    current := state.pieces_buffer[1]
    for i in 1..<GRID_HORZSIZE-1-len(current) {
        for j in 1..<GRID_VERTSIZE - 1 {
            if(!check_collision(state, current, i, j)){
                return false
            }
        }
    }
    return true
}*/

check_collision :: proc(state: State, piece: [][]Grid_Square, i: int, j: int) -> bool{ //@COLLISIONCHECK
    collision: bool = false
    a:int = 0
    b:int = 0


collision_loop:\
    for array in piece {
        for block in array {
            if block == .Block && (state.grid[i+b][j+a] == .Block || state.grid[i+b][j+a] == .Full){
                fmt.printf("check_collision: collision found at: (a,b,i,j,grid_at)=%v,%s.\n",
                    [4]int{a,b,i,j},state.grid[i+b][j+a])
                collision = true
                break collision_loop
            }
            b += 1
        }
        b = 0
        a += 1
    }

    return collision
}

blocks_to_clear :: proc(grid: [GRID_HORZSIZE][GRID_VERTSIZE + 1]Grid_Square) -> ([dynamic]i32,[dynamic]i32){
    cleared: bool
    lines: [dynamic]i32 = {}
    cols: [dynamic]i32 = {}

    for i in 1..<GRID_HORZSIZE-1{
        cleared = true
        //fmt.printf("clearing line %i\n",i)
        for j in 1..<GRID_VERTSIZE-1 {
            if grid[j][i] == .Empty {
                //fmt.printf("\t(column is empty: %d)\n",j)
                cleared = false
            }
        }
        if(cleared){
            fmt.printf("lines:%v\n",lines)
            append(&lines, i32(i))
        }
    }

    for i in 1..<GRID_VERTSIZE-1{
        cleared = true
        //fmt.printf("clearing column %i\n",i)
        for j in 1..<GRID_HORZSIZE-1{
            if(grid[i][j] == .Empty){
                //fmt.printf("\t(at row %i is empty)\n",j)
                cleared = false
            }
        }
        if(cleared){
            append(&cols, i32(i))
            fmt.printf("cols:%v\n",cols)
        }
    }
    return lines, cols
}

draw_game :: proc(state: ^State, config: ^Configuration)->bool{
    rl.BeginDrawing()
    defer rl.EndDrawing()

    //pieces_to_draw := &(state^.pieces_buffer);
    //colors_to_draw := &(state^.colors_buffer);

    previous := state^.pieces_buffer[0]
    current := state^.pieces_buffer[1]
    next := state^.pieces_buffer[2]

    previous_color := state^.colors_buffer[0]
    current_color := state^.colors_buffer[1]
    next_color := state^.colors_buffer[2]

    rl.ClearBackground(rl.RAYWHITE)
    drawn := false


    if state^.game_over {
        text :: "Press ENTER to play again"
        rl.DrawText(text, rl.GetScreenWidth()/2 - rl.MeasureText(text, 20)/2,
            rl.GetScreenHeight()/2 - 50, 20, rl.RED)
    } else if state^.pause { 
        text :: "Press <P> to\nresume the game"
        rl.DrawText(text, rl.GetScreenWidth()/2 - rl.MeasureText(text, 20)/2,
            rl.GetScreenHeight()/2 - 50, 20, rl.GRAY)
    }

    offset := [2]i32 {
        config^.SCREEN_WIDTH/2 - (GRID_HORZSIZE*config^.SQUARE_SIZE/2) ,
        config^.SCREEN_HEIGHT/2 - (GRID_HORZSIZE*config^.SQUARE_SIZE/2),
    }
    offset2 := [2]i32{}

    controller := offset.x

    for j in 0..<GRID_VERTSIZE {
        for i in 0..<GRID_HORZSIZE {
            #partial switch(state^.grid[i][j]){ //#partial switch
                case .Empty:
                    rl.DrawLine(offset.x, offset.y, offset.x + config^.SQUARE_SIZE, offset.y, config^.color_configuration.Empty)
                    rl.DrawLine(offset.x, offset.y, offset.x, offset.y + config^.SQUARE_SIZE, config^.color_configuration.Empty)
                    rl.DrawLine(offset.x + config^.SQUARE_SIZE, offset.y, offset.x + config^.SQUARE_SIZE,offset.y, config^.color_configuration.Empty)
                    rl.DrawLine(offset.x, offset.y, offset.x + config^.SQUARE_SIZE, offset.y, config^.color_configuration.Empty)
                case .Full:
                    rl.DrawRectangle(offset.x,offset.y, config^.SQUARE_SIZE, config^.SQUARE_SIZE, config^.color_configuration.Full)
                case .Block:
                    rl.DrawRectangle(offset.x,offset.y, config^.SQUARE_SIZE, config^.SQUARE_SIZE, state^.colors[i][j])
                case:
                    fmt.printf("Error: block type not recognized.")
            }
            /* a part of the update, but for optimization this will stay here */
            if !state^.pause && f32(offset.x) < state^.mouse_position.x \
                 && state^.mouse_position.x < f32(i32(offset.x) + config^.SQUARE_SIZE){
                if f32(offset.y) < state^.mouse_position.y &&\
                     state^.mouse_position.y < f32(i32(offset.y) + config^.SQUARE_SIZE)\
                     && rl.IsMouseButtonPressed(.LEFT){
                    //fmt.printf("selected color: %v\n" ,current_color)

                    if(check_collision(state^, current, i, j)){ //@COLLISIONCHECK
                        offset.x += config^.SQUARE_SIZE
                        break
                    }

                    a := 0
                    b := 0

                    for array in current {
                        for block in array {
                            if(block == .Block){
                                state^.grid[i+b][j+a] = .Block
                                state^.colors[i+b][j+a] = current_color
                            }
                            b += 1
                        }
                        b = 0
                        a += 1
                    }
                    state^.to_delete = true;

                    //fmt.printf("lines,cols: %v,%v\n",lines,cols)
                    fmt.printf("current:(%v)->%v->%v\n",previous,current,next)
                    state^.pieces_buffer[0] = current
                    state^.pieces_buffer[1] = next
                    state^.pieces_buffer[2] = rand.choice(config^.pieces)

                    fmt.printf("state^.colors:(%d)->%d->%d\n",previous_color,current_color,next_color)
                    state^.colors_buffer[0] = current_color
                    state^.colors_buffer[1] = next_color
                    state^.colors_buffer[2] = rand.choice(state^.palette)
                    if(state^.colors_buffer[2][3] == 0){
                        state^.colors_buffer[2] = rl.RED;
                    }
                    drawn = true
                }
            }
            offset.x += config^.SQUARE_SIZE
        }
        offset.x = controller
        offset.y += config^.SQUARE_SIZE
    }

preview:\
    if(state^.preview_activated){
        controller := rl.GetScreenWidth()-config^.SQUARE_SIZE*i32(len(current)+1)
        offset2.x = controller
        offset2.y = 0

        a := 0
        b := 0

        iterations := 0
        for array in current{
            //fmt.printf("array:%v:%d\n",array,iterations)
            for block in array {

                if(block == .Block){
                    //fmt.printf("a: %d, b: %d\n",a,b)
                    rl.DrawRectangle(offset2.x,offset2.y, config^.SQUARE_SIZE, config^.SQUARE_SIZE, rl.BLACK)
                } else if (block == .Empty) {
                    rl.DrawRectangle(offset2.x,offset2.y, config^.SQUARE_SIZE, config^.SQUARE_SIZE, rl.RAYWHITE)
                }

                b += 1
                offset2.x+=config^.SQUARE_SIZE
            }
            offset2.x = controller
            offset2.y += config^.SQUARE_SIZE
            b = 0
            a += 1
            iterations+=1
        }
    }
    return drawn
}


