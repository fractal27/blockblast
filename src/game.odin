//!/usr/bin/env odin build game.odin -file -debug

/*
 * game.odin 0.1.0
 * Beta version of a simple 2d game
===========================================================
Label statements:
    //@REMOVED(0.1)  /*the structure was to make movable tiles*/
    //@REMOVED(0.2)  /*Now configuration struct has 2 fields: Full, Empty, and Fading*/
    //@CLEARLINES    /*To clear the lines and the columns full.*/
    //@COLLISIONCHECK/**/
===========================================================
TODO: Publish onto github
######################## TODO: Preview#####################
######################## TODO: Colors #####################
######################## TODO: Pieces #####################
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
    //@REMOVED(0.1)Moving: rl.Color,
    Empty, Full, Fading: rl.Color 
}

SQUARE_SIZE :: 30
SCREEN_WIDTH :: 400
SCREEN_HEIGHT :: 500

GRID_HORZSIZE :: 10
GRID_VERTSIZE :: 10

game_over := false
pause := false
to_delete := false
preview_activated :: true


grid:        [GRID_HORZSIZE][GRID_VERTSIZE+1]Grid_Square
colors:      [GRID_HORZSIZE][GRID_VERTSIZE+1]rl.Color
//grid_moving: [GRID_HORZSIZE][GRID_VERTSIZE+1]Grid_Square

piece_position: [2]i32
mouse_position : rl.Vector2
pieces: [][][]Grid_Square = {
    {{.Block,.Block,.Block},{.Block,.Block,.Block}},
    {{.Block,.Block},{.Block,.Block}},
    {{.Block,.Block,.Block},{.Empty,.Block}},
    {{.Empty,.Block},{.Block,.Block,.Block}},
    {{.Block},{.Block,.Block},{.Block}},
    {{.Empty,.Block},{.Block}},
    {{.Empty,.Block},{.Block}}
};




main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test")
    defer rl.CloseWindow()


    //initialization
    color_configuration := Colors {
        Empty=rl.LIGHTGRAY,
        Full=rl.GRAY,
        //@REMOVED(0.1)Moving=rl.DARKGRAY,
        //@REMOVED(0.2)Block=rl.BLUE,
        Fading = rl.RED
    }

    palette := []rl.Color {
        rl.LIGHTGRAY,
        rl.YELLOW,
        rl.RED,
        rl.GREEN,
        rl.BLUE,
        rl.PURPLE,
        rl.BROWN,
        rl.BEIGE
    }
    pieces_buffer: [3][][]Grid_Square = {rand.choice(pieces),rand.choice(pieces),rand.choice(pieces)}
    colors_buffer:  [3]rl.Color = {rand.choice(palette),rand.choice(palette),rand.choice(palette)}

    init_game()

    rl.SetTargetFPS(60) //main loop
    for !rl.WindowShouldClose(){
        update_game()
        draw_game(color_configuration,palette,&pieces_buffer,&colors_buffer)
    }
}

init_game :: proc() {

    piece_position = {0, 0}
    to_delete = false
    
    grid = {}

    for j in 0..<GRID_VERTSIZE {
        for i in 0..<GRID_HORZSIZE {
            switch {
            case j == GRID_VERTSIZE - 1,
                 i == GRID_HORZSIZE-1,
                 i == 0,
                 j == 0:
                grid[i][j] = .Full
            }
        }
    }
}

update_game :: proc(){
    if game_over && rl.IsKeyPressed(.ENTER){
        init_game()
        game_over = false
        return
    } else if rl.IsKeyPressed(.P) {
        pause = !pause
    }

    if pause {
        return
    }

    mouse_position = rl.GetMousePosition()
    if to_delete {
        //@CLEARLINES
        lines, cols := blocks_to_clear()
        defer delete(lines)
        defer delete(cols)


        for line in lines {
            for i in 1..<GRID_HORZSIZE-1{
                grid[i][line] = .Empty
            }
        }

        for col in cols {
            for j in 1..<GRID_VERTSIZE-1{
                grid[col][j] = .Empty
            }
        }

        to_delete = false
    }
}

check_collision::proc(piece: [][]Grid_Square, i: int, j: int) -> bool{
    collision: bool = false
    a:int = 0
    b:int = 0


collision_loop: for array in piece {
        //fmt.printf("array:%v\n",array)
        for block in array {
            if block == .Block && (grid[i+b][j+a] == .Block || grid[i+b][j+a] == .Full){
                fmt.printf("check_collision: collision found at: (a,b,i,j,grid_at)=%v,%s.\n",[4]int{a,b,i,j},grid[i+b][j+a])
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

blocks_to_clear :: proc() -> ([dynamic]i32,[dynamic]i32){
    cleared: bool
    lines: [dynamic]i32 = {}
    cols: [dynamic]i32 = {}
    //i: i32
    //j: i32

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
        //fmt.printf("\t(at row %i is empty)\n",j)
            if(grid[i][j] == .Empty){
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

draw_game :: proc(color_configuration: Colors, palette: []rl.Color, pieces_to_draw: ^[3][][]Grid_Square, colors_to_draw: ^[3]rl.Color)->bool{
    rl.BeginDrawing()
    defer rl.EndDrawing()

    previous := pieces_to_draw^[0]
    current := pieces_to_draw^[1]
    next := pieces_to_draw^[2]

    previous_color := colors_to_draw^[0]
    current_color := colors_to_draw^[1]
    next_color := colors_to_draw^[2]

    rl.ClearBackground(rl.RAYWHITE)
    drawn := false


    if game_over {
        text :: "Press ENTER to play again"
        rl.DrawText(text, rl.GetScreenWidth()/2 - rl.MeasureText(text, 20)/2,
            rl.GetScreenHeight()/2 - 50, 20, rl.RED)
    } else if pause { 
        text :: "Press <P> to\nresume the game"
        rl.DrawText(text, rl.GetScreenWidth()/2 - rl.MeasureText(text, 20)/2,
            rl.GetScreenHeight()/2 - 50, 20, rl.GRAY)
    }

    offset := [2]i32 {
        SCREEN_WIDTH/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) ,//- 50,
        SCREEN_HEIGHT/2 - (GRID_HORZSIZE*SQUARE_SIZE/2),// - 50,
//((GRID_VERTSIZE-1)*SQUARE_SIZE/2) + SQUARE_SIZE*2 - 50,
    }
    offset2 := [2]i32{}

    controller := offset.x

    for j in 0..<GRID_VERTSIZE {
        for i in 0..<GRID_HORZSIZE {
            #partial switch(grid[i][j]){ //#partial switch
                case .Empty:
                    rl.DrawLine(offset.x, offset.y, offset.x + SQUARE_SIZE, offset.y, color_configuration.Empty)
                    rl.DrawLine(offset.x, offset.y, offset.x, offset.y + SQUARE_SIZE, color_configuration.Empty)
                    rl.DrawLine(offset.x + SQUARE_SIZE, offset.y, offset.x + SQUARE_SIZE,offset.y, color_configuration.Empty)
                    rl.DrawLine(offset.x, offset.y, offset.x + SQUARE_SIZE, offset.y, color_configuration.Empty)
                //@REMOVED(0.1)case .Moving:
                    //@REMOVED(0.1)rl.DrawRectangle(offset.x,offset.y, SQUARE_SIZE, SQUARE_SIZE, color_configuration.Moving)
                case .Full:
                    rl.DrawRectangle(offset.x,offset.y, SQUARE_SIZE, SQUARE_SIZE, color_configuration.Full)
                case .Block:
                    rl.DrawRectangle(offset.x,offset.y, SQUARE_SIZE, SQUARE_SIZE, colors[i][j])
                case:
                    fmt.printf("Error: block type not recognized.")
            }

            /* a part of the update, but for optimization this will stay here */
            if !pause && f32(offset.x) < mouse_position.x && mouse_position.x < f32(offset.x) + SQUARE_SIZE{
                if f32(offset.y) < mouse_position.y && mouse_position.y < f32(offset.y) + SQUARE_SIZE\
                    && rl.IsMouseButtonPressed(.LEFT){
                    //fmt.printf("selected color: %v\n" ,current_color)

                    if(check_collision(current, i, j)){ //@COLLISIONCHECK
                        offset.x += SQUARE_SIZE
                        break
                    }

                    a := 0
                    b := 0

                    for array in current {
                        for block in array {
                            if(block == .Block){
                                grid[i+b][j+a] = .Block
                                colors[i+b][j+a] = current_color
                            }
                            b += 1
                        }
                        b = 0
                        a += 1
                    }
                    /*lines, cols := blocks_to_clear() 
                    defer delete(lines)
                    defer delete(cols)*/
                    to_delete = true;
                    //fmt.printf("lines,cols: %v,%v\n",lines,cols)
                    //fmt.printf("current:(%v)->%v->%v\n",previous,current,next)
                    pieces_to_draw^[0] = current
                    pieces_to_draw^[1] = next
                    pieces_to_draw^[2] = rand.choice(pieces)

                    //fmt.printf("colors:(%d)->%d->%d\n",previous_color,current_color,next_color)
                    colors_to_draw^[0] = current_color
                    colors_to_draw^[1] = next_color
                    colors_to_draw^[2] = rand.choice(palette)
                    drawn = true
                }
            }
            offset.x += SQUARE_SIZE
        }
        offset.x = controller
        offset.y += SQUARE_SIZE
    }

preview:\
    if(preview_activated){
        controller := rl.GetScreenWidth()-i32(SQUARE_SIZE*(len(current)+1))
        offset2.x = controller
        offset2.y = 0

        a := 0
        b := 0

        /*if(check_collision(next,i,j)) {
            break preview
        }*/
        iterations := 0
        for array in current{
            //fmt.printf("array:%v:%d\n",array,iterations)
            for block in array {

                //fmt.printf("offset2:%v,WINDOW:%v\n",offset2,[2]i32{SCREEN_WIDTH,SCREEN_HEIGHT})
                if(block == .Block){
                    //fmt.printf("a: %d, b: %d\n",a,b)
                    rl.DrawRectangle(offset2.x,offset2.y, SQUARE_SIZE, SQUARE_SIZE, rl.BLACK)
                } else if (block == .Empty) {
                    rl.DrawRectangle(offset2.x,offset2.y, SQUARE_SIZE, SQUARE_SIZE, rl.RAYWHITE)
                }
                b += 1
                offset2.x+=SQUARE_SIZE
            }
            offset2.x = controller
            offset2.y += SQUARE_SIZE
            b = 0
            a += 1
            iterations+=1
        }
    }
    return drawn
}


