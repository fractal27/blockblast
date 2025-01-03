//!/usr/bin/env odin build game.odin -file

/*
 * game.odin 0.2.0
 * Beta version of a simple 2d game
===========================================================
Label statements to jump searching(in vim):
    //@JMP              /*To jump here*/
    //@CLEARLINES       /*To clear the lines and the columns full.*/
    //@COLLISIONCHECK(1)/*first to indicate the function*/
    //@COLLISIONCHECK(2)/*second to indicate the point where it checks*/
    //@ROUNDEDBORDER
    //@IINIT(1)
    //@IINIT(2)
    //@MAINLOOP
    //@DEINIT
    //@PREVIEW
===========================================================
TODO: Configuration(drop-down gui and struct)
######################## TODO: FX and Textures ############
######################## TODO: Publish onto github#########
######################## TODO: Preview#####################
######################## TODO: Colors #####################
######################## TODO: Pieces #####################
*/


package example_gui
import "core:os"
import "core:math/rand"
import "core:math"
import "core:fmt"
import rl "vendor:raylib"


Grid_Square :: enum u8 {
    Empty,
    //Full,
    Block,
    Fading
}



Colors :: struct {
    //Empty, Full, Fading: rl.Color 
    Empty, Fading: rl.Color
}

BACKGROUND_COLOR :: rl.Color{0x47,0x5b,0xb1,0xff}
                  //rl.Color{0x4a,0x5a,0x77,0xff}
INNER_COLOR :: rl.Color{0x24,0x2b,0x51,0xff} //rl.Color{0x39,0x49,0x66,0xff}
INNER_BORDER :: rl.Color{0x1d,0x25,0x4c,0xff}

SQUARE_SIZE   :: 50
SCREEN_WIDTH  :: 900
SCREEN_HEIGHT :: 800

GRID_HORZSIZE :: 8
GRID_VERTSIZE :: 8

ROUNDEDNESS_EMPTY :: f32(0.15)
ROUNDEDNESS_CONTOUR :: f32(0.07)




State :: struct {
    game_over: bool,
    pause: bool,
    to_delete: bool,
    preview_activated: bool,

    grid:           [GRID_HORZSIZE][GRID_VERTSIZE+1]Grid_Square,
    colors:         [GRID_HORZSIZE][GRID_VERTSIZE+1]rl.Color,

    palette:        []rl.Color,
    texture:        rl.Texture2D,
    fx_clear:       rl.Sound,
    //TODO: fx_collision

    pieces_buffer:  [3][][]Grid_Square,
    colors_buffer:  [3]rl.Color,
    mouse_position: rl.Vector2,

    rounded_border_activated: bool,
    color_configuration: Colors
}

pieces: [][][]Grid_Square = {
    {{.Block,.Block,.Block},{.Block,.Block,.Block}},
    {{.Block,.Block},{.Block,.Block}},
    {{.Block,.Block,.Block},{.Empty,.Block}},
    {{.Empty,.Block},{.Block,.Block,.Block}},
    {{.Block},{.Block,.Block},{.Block}},
    {{.Empty,.Block},{.Block}},
    {{.Empty,.Block},{.Block}}
};





init_state :: proc(state: ^State, img: ^rl.Image) {
    //@IINIT(1)
    state^.to_delete = false
    state^.color_configuration = Colors {
        //Empty=rl.BLACK,
        //Full=rl.Color{0x3d,0x6b,0x84,0xff}, //Full=BACKGROUND_COLOR,
        Empty=INNER_COLOR,//rl.Color{0x0c,0x2d,0x48,0xff},
        Fading = rl.RED
    }
    palette := []rl.Color {
        rl.RED,
        rl.YELLOW,
        rl.GREEN,
        rl.BLUE,
        rl.PURPLE,
        rl.BROWN,
        rl.ORANGE,
        rl.LIGHTGRAY
    }

    rl.ImageFlipHorizontal(img);
    rl.ImageResize(img,SQUARE_SIZE,SQUARE_SIZE)
    state^.texture = rl.LoadTextureFromImage(img^);
    state^.fx_clear = rl.LoadSound("../assets/clear.wav")

    state^.pieces_buffer = {
        rand.choice(pieces),
        rand.choice(pieces),
        rand.choice(pieces)
    }
    state^.colors_buffer = {
        rand.choice(palette),
        rand.choice(palette),
        rand.choice(palette)
    }
    state^.palette = palette
    state^.preview_activated = true;
    state^.rounded_border_activated = true;

    fmt.printf("vect:%v\n",state^.palette);
    state^.grid = {}

}



main :: proc() {
    //@IINIT(2)
    state: State
    img: rl.Image 


    rl.InitAudioDevice()
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test")
    defer rl.CloseWindow()

    img = rl.LoadImage("../assets/block.png")
    init_state(&state,&img)    //@IINIT
    defer deinit(&state) //@DEINIT
    rl.UnloadImage(img); //texture has been loaded.

    fmt.printf("color_buffer = %v\n",state.colors_buffer);
    //@MAINLOOP
    rl.SetTargetFPS(60) 
    for !rl.WindowShouldClose(){
        update_game(&state)
        draw_game(&state)
    }

}


update_game :: proc(state: ^State){
    if state^.game_over && rl.IsKeyPressed(.ENTER){
        image := rl.LoadImageFromTexture(state^.texture)
        init_state(state,&image)
        rl.UnloadImage(image)
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
            for i in 0..<GRID_HORZSIZE{
                state^.grid[i][line] = .Empty
            }
            fmt.printf("Playing sound.\n");
            rl.PlaySound(state^.fx_clear)
        }

        for col in cols {
            for j in 0..<GRID_VERTSIZE{
                state^.grid[col][j] = .Empty
            }
            fmt.printf("Playing sound.\n");
            rl.PlaySound(state^.fx_clear)
        }

        state^.to_delete = false
    }
}

check_collision :: proc(state: State, piece: [][]Grid_Square, i: int, j: int) -> bool{ 
    //@COLLISIONCHECK(1)
    collision: bool = false
    a:int = 0
    b:int = 0


collision_loop: for array in piece {
        for block in array {
            if block == .Block && (state.grid[i+b][j+a] == .Block){//|| state.grid[i+b][j+a] == .Full){
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

    for i in 0..<GRID_HORZSIZE{
        cleared = true
        //fmt.printf("clearing line %i\n",i)
        for j in 0..<GRID_VERTSIZE {
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

    for i in 0..<GRID_VERTSIZE{
        cleared = true
        //fmt.printf("clearing column %i\n",i)
        for j in 0..<GRID_HORZSIZE{
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

draw_game :: proc(state: ^State)->bool{
    rl.BeginDrawing()
    defer rl.EndDrawing()

    pieces_to_draw := &state.pieces_buffer;
    colors_to_draw := &state.colors_buffer;

    previous := state^.pieces_buffer[0]
    current := state^.pieces_buffer[1]
    next := state^.pieces_buffer[2]

    previous_color := state^.colors_buffer[0]
    current_color := state^.colors_buffer[1]
    next_color := state^.colors_buffer[2]

    rl.ClearBackground(BACKGROUND_COLOR)
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
        SCREEN_WIDTH/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) ,
        SCREEN_HEIGHT/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) - 50,
    }
    offset2 := [2]i32{}

    controller := offset.x

    for j in 0..<GRID_VERTSIZE {
        for i in 0..<GRID_HORZSIZE {
            #partial switch(state^.grid[i][j]){ //#partial switch
                case .Empty:
                    rec := rl.Rectangle{f32(offset.x),f32(offset.y), SQUARE_SIZE-2, SQUARE_SIZE-2}
                    rl.DrawRectangleRounded(rec,ROUNDEDNESS_EMPTY,0, rl.Fade(state^.color_configuration.Empty,0.3))
                    /*rl.DrawLine(offset.x, offset.y, offset.x + SQUARE_SIZE, offset.y, INNER_BORDER)
                    rl.DrawLine(offset.x, offset.y, offset.x, offset.y + SQUARE_SIZE, INNER_BORDER)
                    rl.DrawLine(offset.x + SQUARE_SIZE, offset.y, offset.x + SQUARE_SIZE,offset.y, INNER_BORDER)
                    rl.DrawLine(offset.x, offset.y, offset.x + SQUARE_SIZE, offset.y, INNER_BORDER)*/
                //case .Full:
                    //rl.DrawRectangle(offset.x,offset.y, SQUARE_SIZE, SQUARE_SIZE, state^.color_configuration.Full)
                case .Block:
                    rl.DrawTexture(state^.texture, offset.x, offset.y, state^.colors[i][j])
                case:
                    fmt.printf("Error: block type not recognized.")
            }
            /* a part of the update function, but for optimization this will stay here */
            if !state^.pause && f32(offset.x) < state^.mouse_position.x \
                 && state^.mouse_position.x < f32(offset.x) + SQUARE_SIZE{
                if f32(offset.y) < state^.mouse_position.y &&\
                     state^.mouse_position.y < f32(offset.y) + SQUARE_SIZE\
                     && rl.IsMouseButtonPressed(.LEFT){
                    //fmt.printf("selected color: %v\n" ,current_color)

                    if(check_collision(state^, current, i, j)){ //@COLLISIONCHECK(2)
                        offset.x += SQUARE_SIZE
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
                    //fmt.printf("current:(%v)->%v->%v\n",previous,current,next)
                    pieces_to_draw^[0] = current
                    pieces_to_draw^[1] = next
                    pieces_to_draw^[2] = rand.choice(pieces)

                    fmt.printf("state^.colors:(%d)->%d->%d\n",previous_color,current_color,next_color)
                    colors_to_draw^[0] = current_color
                    colors_to_draw^[1] = next_color
                    colors_to_draw^[2] = rand.choice(state^.palette)
                    if(colors_to_draw^[2][3] == 0){
                        colors_to_draw^[2] = rl.RED;
                    }
                    drawn = true
                }
            }
            offset.x += SQUARE_SIZE
        }
        offset.x = controller
        offset.y += SQUARE_SIZE
    }
rounded_border: if(state^.rounded_border_activated){
        //@ROUNDEDBORDER
        offset = [2]i32 {
            SCREEN_WIDTH/2 - (GRID_HORZSIZE*SQUARE_SIZE/2)- 15 ,
            SCREEN_HEIGHT/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) - 65,
        }
        rec := rl.Rectangle{f32(offset.x),f32(offset.y),SQUARE_SIZE*GRID_HORZSIZE+30,SQUARE_SIZE*GRID_VERTSIZE+30}
        rl.DrawRectangleRounded(rec,ROUNDEDNESS_CONTOUR,0, state^.color_configuration.Empty-{0x11,0x11,0x11,0xf0})

    }



preview:\
    if(state^.preview_activated){//@PREVIEW
        offset2 := [2]i32 {
            SCREEN_WIDTH/2 - i32(len(current)*SQUARE_SIZE/2) ,
            SCREEN_HEIGHT - i32(SQUARE_SIZE*(len(current)+1))
        }
        controller = offset2.x

        a := 0
        b := 0

        iterations := 0
        for array in current{
            //fmt.printf("array:%v:%d\n",array,iterations)
            for block in array {

                //fmt.printf("offset2:%v,WINDOW:%v\n",offset2,[2]i32{SCREEN_WIDTH,SCREEN_HEIGHT})
                if(block == .Block){
                    //fmt.printf("a: %d, b: %d\n",a,b)
                    //rl.DrawRectangle(offset2.x,offset2.y, SQUARE_SIZE, SQUARE_SIZE, current_color)
                    rl.DrawTexture(state^.texture, offset2.x, offset2.y, current_color)
                } else if (block == .Empty) {
                    rl.DrawRectangle(offset2.x,offset2.y, SQUARE_SIZE, SQUARE_SIZE, BACKGROUND_COLOR)
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

deinit :: proc(state: ^State){ //@DEINIT
    rl.UnloadSound(state^.fx_clear)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}
