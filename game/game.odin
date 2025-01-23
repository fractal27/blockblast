//!/usr/bin/env odin build game.odin -file

/*
 * game.odin v0.2.2
 * Beta version of a simple 2d game
 ===========================================================
 Label statements to jump searching:
//@JMP              /*To jump here*/
//@CLEARLINES       /*To clear the lines and the columns full.*/
//@COLLISIONCHECK(1)/*second to indicate the point where it checks*/
//@COLLISIONCHECK(2)/*first to indicate the function*/
//@ROUNDEDBORDER
//@IINIT(1)
//@IINIT(2)
//@MAINLOOP
//@PREVIEW
===========================================================
TODO:drop-down gui and struct
TODO: Configuration
TODO: Fix bugs on win32(windows)
 ######################## TODO:  C-z button and fix sound and a graphic bug
 ######################## TODO:  Fix graphic bug ############
 ######################## TODO:  FX and Textures ############
 ######################## TODO:  Publish onto github#########
 ######################## TODO:  Preview#####################
 ######################## TODO:  Colors #####################
 ######################## TODO:  Pieces #####################
*/


package game

import "core:os"
import "core:math/rand"
import "core:math"
import "core:fmt"
import "core:mem"
import "core:time"
import "core:strings"
import "core:c/libc"
import rl "vendor:raylib"

Grid_Square :: enum u8 {
  Empty, //Full,
  Block,
  Fading
}

error :: distinct []i32 //debugging info

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
SCREEN_HEIGHT :: 750

GRID_HORZSIZE :: 8
GRID_VERTSIZE :: 8

ROUNDEDNESS_EMPTY :: f32(0.15)
ROUNDEDNESS_CONTOUR :: f32(0.07)
DEFAULT_PALETTE:[]rl.Color : {
    rl.Color{0xff,0x00,0x00,0xff},
    rl.Color{0x00,0xff,0x00,0xff},
    rl.Color{0x00,0x00,0xff,0xff},
    rl.Color{0xff,0xff,0x00,0xff},
    rl.Color{0x00,0xff,0xff,0xff},
    rl.Color{0xff,0x00,0xff,0xff}
}



State :: struct {
    game_over: bool,
    pause: bool,
    to_delete: bool,
    preview_activated: bool,

    grid:           [GRID_HORZSIZE][GRID_VERTSIZE+1]Grid_Square,
    colors:         [GRID_HORZSIZE][GRID_VERTSIZE+1]rl.Color,
    reversible:     [dynamic][2]int,
    palette:        []rl.Color,
    texture:        rl.Texture2D,
    font: rl.Font,
    font_gameover: rl.Font,
    fx_clear:       rl.Sound,
    fx_place:       rl.Sound,
    fx_collision:   rl.Sound,
    fx_gameover:    rl.Sound,

    pieces_buffer:  [5][][]Grid_Square,
    colors_buffer:  [5]rl.Color,
    mouse_position: rl.Vector2,

    rounded_border_activated: bool,
    control_pressed: bool,
    gameover_drawn: bool,
    color_configuration: Colors,
    XP: u32,
    cleared: i32, //only for debugging.
    combo: u32,   //only for debugging.
    str: [^]u8
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



check_collision :: proc(state: State, piece: [][]Grid_Square, i: int, j: int,sound:bool=true) -> (bool, error){ 
    //@COLLISIONCHECK(2)
    collision : bool = false
    a:int = 0
    b:int = 0
    err: error
    //fmt.printf("\t\e[43m-- collision check for inserting(i=%d,j=%d) --\e[0m",i,j)

    collision_loop_2:\
    for array in piece {
        for block in array {
            if    i+b <= GRID_VERTSIZE-1\
               && j+a <= GRID_HORZSIZE-1{
                    if block == .Block && (state.grid[i+b][j+a] == .Block){
                        //|| state.grid[i+b][j+a] == .Full){
                        //fmt.println("\e[31mcollision found at",i+b,j+a,"\e[0m")
                        collision = true
                        err := []int{a,b,i,j}
                        break collision_loop_2
                    }
            } else {
                    //fmt.println("\e[31mcollision_error: position out of bounds:",i+b,j+a,"\e[0m")
                    collision = true
                    err := []int{a,b,i,j}
                    break collision_loop_2
            }
            b += 1
        }
        b = 0
        a += 1
    }
    /*if !collision {
      fmt.println("piece ",piece," not collide, i,j,a,b=",i,j,a,b)
      }*/
    if collision && sound{
        rl.PlaySound(state.fx_collision)
    }
    return collision,err
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
            fmt.printf("to clear(lines):%v\n",lines)
            append(&lines, i32(i))
        }
    }

    for i in 0..<GRID_VERTSIZE{
        cleared = true
        for j in 0..<GRID_HORZSIZE{
            if(grid[i][j] == .Empty){
                cleared = false
            }
        }
        if(cleared){
            append(&cols, i32(i))
            fmt.printf("to clear(cols):%v\n",cols)
        }
    }
    return lines, cols
}






init_state :: proc(state: ^State, img: ^rl.Image,palette: []rl.Color = DEFAULT_PALETTE,assets_dir: string = "../assets/") {
    //@IINIT(1)
    state^.to_delete = false
    state^.color_configuration = Colors {
        //Empty=rl.BLACK,
        //Full=rl.Color{0x3d,0x6b,0x84,0xff}, //Full=BACKGROUND_COLOR,
        Empty=INNER_COLOR,//rl.Color{0x0c,0x2d,0x48,0xff},
        Fading = rl.RED
    }
    state^.palette = make([]rl.Color,len(palette))
    for i in 0..<len(palette){
        state^.palette[i] = palette[i]
    }
    //palette := 

    rl.ImageFlipHorizontal(img);
    rl.ImageResize(img,SQUARE_SIZE,SQUARE_SIZE)
    state^.texture = rl.LoadTextureFromImage(img^);
    state^.fx_clear = rl.LoadSound(strings.unsafe_string_to_cstring(strings.concatenate({assets_dir,"/clear.wav"})))
    state^.fx_place = rl.LoadSound(strings.unsafe_string_to_cstring(strings.concatenate({assets_dir,"/place_block2.mp3"})))
    state^.fx_collision = rl.LoadSound(strings.unsafe_string_to_cstring(strings.concatenate({assets_dir,"/collision.mp3"})))
    state^.fx_gameover = rl.LoadSound(strings.unsafe_string_to_cstring(strings.concatenate({assets_dir,"/failed.wav"})))

    state^.pieces_buffer = {
        rand.choice(pieces),
        rand.choice(pieces),
        rand.choice(pieces),
        rand.choice(pieces),
        {}
    }
    state^.colors_buffer = {
        rand.choice(state^.palette),
        rand.choice(state^.palette), //corrente
        rand.choice(state^.palette),
        rand.choice(state^.palette),
        rl.Color{0,0,0,0} //prossimo prossimo
    }


    state^.preview_activated = true;
    state^.rounded_border_activated = true;

    state^.font = rl.LoadFontEx("../assets/fonts/Roboto-Black.ttf",20,nil,0)
    state^.font_gameover = rl.LoadFontEx("../assets/fonts/a_glitch_in_time.ttf",40,nil,0)
    state^.combo = 0
    state^.XP = 0
    state^.str = make([^]u8,100)
    //fmt.printf("palette(init):%v\n",state^.palette);
    state^.grid = {}

}



main :: proc() {
    //@IINIT(2)
    state: State
    img: rl.Image 

    rl.SetConfigFlags(rl.ConfigFlags{/*.WINDOW_RESIZABLE,*/.WINDOW_MAXIMIZED});

    rl.InitAudioDevice()
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test")
    defer rl.CloseWindow()
    rl.SetExitKey(.Q)

    img = rl.LoadImage("../assets/block.png")
    init_state(&state,&img)    //@IINIT

    defer rl.UnloadSound(state.fx_clear)
    defer rl.UnloadSound(state.fx_place)
    defer rl.UnloadSound(state.fx_collision)
    defer rl.CloseAudioDevice()

    rl.UnloadImage(img); //texture has been loaded.

    //fmt.printf("color_buffer = %v\n",state.colors_buffer);
    //@MAINLOOP
    rl.SetTargetFPS(70)
    for !rl.WindowShouldClose(){
        update_game(&state)
        draw_game(&state)
    }

}


update_game :: proc(state: ^State){
    game_over_check:\
    if state^.game_over {
        if !rl.IsKeyPressed(.ENTER){
            break game_over_check
        }
        image := rl.LoadImageFromTexture(state^.texture)
        init_state(state,&image)
        rl.UnloadImage(image)
        state^.game_over = false
        state^.gameover_drawn = false
        return
    } else if rl.IsKeyPressed(.P) {
        state^.pause = !state^.pause
    }

    if state^.pause {
        return
    }

    if rl.IsKeyPressed(.LEFT_CONTROL){
        state^.control_pressed = true
    } else if rl.IsKeyReleased(.LEFT_CONTROL){
        state^.control_pressed = false
    }

    if state^.control_pressed && rl.IsKeyPressed(.Z){
        //C-z pressed
        if ((len(state^.pieces_buffer[0]) > 0)\
            && (len(state^.colors_buffer[0]) > 0)\
            && state^.combo == 0){
            //fmt.println("pieces_buffer before:",state^.pieces_buffer)
            /*please do not reorder.*/
            state^.pieces_buffer[3] = state^.pieces_buffer[2]
            state^.pieces_buffer[2] = state^.pieces_buffer[1]
            state^.pieces_buffer[4] = state^.pieces_buffer[3]
            state^.pieces_buffer[1] = state^.pieces_buffer[0]
            state^.pieces_buffer[0] = {}

            //fmt.println("pieces_buffer after:",state^.pieces_buffer)
            /*please do not reorder.*/
            state^.colors_buffer[3] = state^.colors_buffer[2]
            state^.colors_buffer[2] = state^.colors_buffer[1]
            state^.colors_buffer[4] = state^.colors_buffer[3]
            state^.colors_buffer[1] = state^.colors_buffer[0]
            state^.colors_buffer[0] = rl.Color {0,0,0,0}
            //fmt.println("colors_buffer after:",state^.colors_buffer)
            // reverse state
            pos: [2]int
            for pos in state^.reversible {
                state^.grid[pos.x][pos.y] = .Empty
                //state^.colors[x][y] = rl.Color{0,0,0,0}
            }
            clear(&(state^.reversible))
            //fmt.println("other -- 1 -- reversible::after =",state^.reversible)

        }
    }
    if state^.to_delete {
        //@CLEARLINES
        lines, cols := blocks_to_clear(state^.grid)
        defer delete(lines)
        defer delete(cols)

        combined_len := u32(len(lines)+len(cols))
        mult: u32

        if combined_len > 0{
            mult = 1<<(combined_len-1)
            state^.combo += mult*50;
            state^.XP += combined_len*state^.combo
            //fmt.println("mult:",mult,"len(lines):",len(lines),"len(cols):",len(cols))
        } else {
            mult = 0
            state^.combo = 0
            if is_gameover(state);state^.game_over{
                return
            }
        }
        for line in lines {
            for i in 0..<GRID_HORZSIZE{
                state^.grid[i][line] = .Empty
            }
            //fmt.printf("Playing sound.\n");
            rl.PlaySound(state^.fx_clear)
        }

        for col in cols {
            for j in 0..<GRID_VERTSIZE{
                state^.grid[col][j] = .Empty
            }
            //fmt.printf("Playing sound.\n");
            rl.PlaySound(state^.fx_clear)
        }
        state^.to_delete = false
    }

    state^.mouse_position = rl.GetMousePosition()

    offset := [2]f32 {
        SCREEN_WIDTH/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) ,
        SCREEN_HEIGHT/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) - 50,
    }

    collisioncheck:\
    if(state^.mouse_position.x > offset.x\
        && state^.mouse_position.x < offset.x+GRID_HORZSIZE*SQUARE_SIZE-2\
        && state^.mouse_position.y > offset.y\
        && state^.mouse_position.y < offset.y+GRID_HORZSIZE*SQUARE_SIZE-2\
        && rl.IsMouseButtonPressed(.LEFT)) {


        i := int ((state^.mouse_position.x-offset.x)/SQUARE_SIZE)
        j := int ((state^.mouse_position.y-offset.y)/SQUARE_SIZE)

        previous := state^.pieces_buffer[0]
        current := state^.pieces_buffer[1]
        next := state^.pieces_buffer[2]
        next_next := state^.pieces_buffer[3]
        next_next_next := state^.pieces_buffer[3]

        previous_color := state^.colors_buffer[0]
        current_color := state^.colors_buffer[1]
        next_color := state^.colors_buffer[2]
        next_next_color := state^.colors_buffer[3]



        //current = state^.grid[pos.x,pos.y]
        if collision,err := check_collision(state^, current, i, j); collision{  //@COLLISIONCHECK(1)
            break collisioncheck
        }

        state^.colors_buffer[0] = state^.colors_buffer[1]
        state^.colors_buffer[1] = state^.colors_buffer[2]
        state^.colors_buffer[2] = state^.colors_buffer[3] == rl.Color{0,0,0,0} ? rand.choice(state^.palette): state^.colors_buffer[3]
        state^.colors_buffer[3] = state^.colors_buffer[4] == rl.Color{0,0,0,0} ? rand.choice(state^.palette): state^.colors_buffer[4]
        state^.colors_buffer[4] = rl.Color{0,0,0,0}



        //fmt.printf("playing sound for block placement.\n")
        rl.PlaySound(state^.fx_place)

        a := 0
        b := 0

        if len(state^.reversible) > 0 {
            clear(&(state^.reversible))
        }

        for array in current {
            for block in array {
                if(block == .Block){
                    state^.grid[i+b][j+a] = .Block
                    state^.colors[i+b][j+a] = current_color
                    append(&(state^.reversible),[2]int{i+b,j+a})
                }
                b += 1
            }
            b = 0
            a += 1
        }
        //fmt.println("reversible::after =", state^.reversible)
        state^.to_delete = true;

        //fmt.printf("lines,cols: %v,%v\n",lines,cols)
        //fmt.printf("current:(%v)->%v->%v\n",previous,current,next)
        //fmt.println("before:",state^.pieces_buffer)
        state^.pieces_buffer[0] = current
        state^.pieces_buffer[1] = next
        state^.pieces_buffer[2] = len(state^.pieces_buffer[3]) == 0? rand.choice(pieces): state^.pieces_buffer[3]
        state^.pieces_buffer[3] = len(state^.pieces_buffer[4]) == 0? rand.choice(pieces): state^.pieces_buffer[4]
        state^.pieces_buffer[4] = {}
        //fmt.println("after:",state^.pieces_buffer)


        //fmt.printf("state^.colors:(%d)->%d->%d\n",previous_color,current_color,next_color)
        state^.colors_buffer[0] = current_color
        state^.colors_buffer[1] = next_color
        state^.colors_buffer[2] = rand.choice(state^.palette)
        state^.colors_buffer[3] = state^.colors_buffer[4] == rl.Color{0,0,0,0} ? rand.choice(state^.palette)\
        : state^.colors_buffer[4]
        state^.colors_buffer[4] = rl.Color{0,0,0,0}
        state^.colors_buffer[3] = rl.Color{0,0,0,0}


    }
}

is_gameover :: proc(state: ^State){
    //fmt.printf("checking for gameover -- ")
    current := state^.pieces_buffer[1]
    current_gameover := true

    maxlen := 0

    if state^.game_over{
        return 
    }

    for x in current {
        if len(x) > maxlen{
            maxlen = len(x)
        }
    }

    //fmt.println("size-len,size-maxlen:", len(current),maxlen)       
    //fmt.println("\e[33m========= checking for current state =========\e[0m")
    collisionloop:\
    for i in 0..<GRID_VERTSIZE-len(current)+1 {
        for j in 0..<GRID_HORZSIZE-maxlen+1{
            //fmt.println("checking collision with current:",i,j)
            collision,err := check_collision(state^,current,i,j,false);
            if !collision{
                current_gameover = false
                //fmt.println("\e[42mcurrent: non-collision found info:",err,"\e[0m")
                break collisionloop
            }
        }
    }

    state^.game_over = current_gameover

    if state^.game_over {
		fmt.printf("playing gameover sound.\n")
        rl.PlaySound(state^.fx_gameover)
    }
}

draw_game :: proc(state: ^State){
    rl.BeginDrawing()
    defer rl.EndDrawing()

    if state^.game_over {
		text :: "Press ENTER to play again"
		rl.DrawTextEx(state^.font_gameover, text, rl.Vector2{
			f32(rl.GetScreenWidth()/2 - rl.MeasureText(text, state^.font_gameover.baseSize)/2),
			f32(rl.GetScreenHeight()/2 - 50)}, f32(state^.font_gameover.baseSize)*2.0, 1, rl.RED)
        return
    }

    if state^.pause { 
        text :: "Press <P> to\nresume the game"
        rl.DrawTextEx(state^.font, text, rl.Vector2{f32(rl.GetScreenWidth()/2 - rl.MeasureText(text, 15)/2),
            f32(rl.GetScreenHeight()/2 - 50)}, f32(state^.font.baseSize)*2.0, 1, rl.RED)
        return
    }



    previous := state^.pieces_buffer[0]
    current := state^.pieces_buffer[1]
    next := state^.pieces_buffer[2]

    previous_color: rl.Color= state^.colors_buffer[0]
    current_color: rl.Color= state^.colors_buffer[1]
    next_color: rl.Color= state^.colors_buffer[2]

    rl.ClearBackground(BACKGROUND_COLOR)




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
                rl.DrawRectangleRounded(rec,ROUNDEDNESS_EMPTY,0, rl.Fade(state^.color_configuration.Empty,.2))
            case .Block:
                rl.DrawTexture(state^.texture, offset.x, offset.y, state^.colors[i][j])
            case:
                fmt.printf("\e[31mError: block type not recognized.\e[0m")
            }
            offset.x += SQUARE_SIZE
        }
        offset.x = controller
        offset.y += SQUARE_SIZE
    }
    rounded_border:\
    if(state^.rounded_border_activated){
        //@ROUNDEDBORDER
        offset = [2]i32 {
            SCREEN_WIDTH/2 - (GRID_HORZSIZE*SQUARE_SIZE/2)- 15 ,
            SCREEN_HEIGHT/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) - 65,
        }
        rec := rl.Rectangle{f32(offset.x),f32(offset.y),SQUARE_SIZE*GRID_HORZSIZE+30,SQUARE_SIZE*GRID_VERTSIZE+30}
        rl.DrawRectangleRounded(rec,ROUNDEDNESS_CONTOUR,0, state^.color_configuration.Empty-{0x11,0x11,0x11,0xf0})
    } else {
        offset = [2]i32 {
            SCREEN_WIDTH/2 - (GRID_HORZSIZE*SQUARE_SIZE/2)- 10 ,
            SCREEN_HEIGHT/2 - (GRID_HORZSIZE*SQUARE_SIZE/2) - 60,
        }
        rl.DrawRectangle(offset.x,offset.y,SQUARE_SIZE*GRID_HORZSIZE+30,SQUARE_SIZE*GRID_VERTSIZE+30, state^.color_configuration.Empty-{0x11,0x11,0x11,0x00})
    }



    preview:\
    if(state^.preview_activated){//@PREVIEW
		/*i: u32 = rand.uint32()
		fmt.printf("drawing preview %d\n",i)*/
        offset2 := [2]i32 {
            SCREEN_WIDTH/2 - i32(len(current)*SQUARE_SIZE/2) ,
            SCREEN_HEIGHT - i32(SQUARE_SIZE*(len(current)+1))
        }
        controller = offset2.x

        a := 0
        b := 0

        iterations := 0
        for array in current{
            for block in array {
                if(block == .Block){
                    rl.DrawRectangle(offset2.x+2,offset2.y+2, SQUARE_SIZE, SQUARE_SIZE, {0,0,0,0x66}) //SHADOW
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
            /*fmt.printf("(trying to print) -- ")
              if iterations < len(current){
              fmt.printf("array after: %v\n",current[iterations])
              }*/
        }
    }
    if state^.XP > 0 {
		//size := uint(linalg.ceil(linalg.log10(f32(state^.XP))+1)+1)
		xp_str := fmt.caprintf("%d",state^.XP)

        rl.DrawTextEx(state^.font, xp_str, rl.Vector2{\
            f32(rl.GetScreenWidth()/2 - rl.MeasureText(xp_str, 20)/2),
        50.0},
        f32(state^.font.baseSize)*2.0, 1, rl.Fade(rl.RED,0.8))
    } else {
        rl.DrawTextEx(state^.font, "0", rl.Vector2{\
            f32(rl.GetScreenWidth()/2 - rl.MeasureText("0", 20)/2),
        50.0},
        f32(state^.font.baseSize)*2.0, 1, rl.Fade(rl.RED,0.8))
    }
}


