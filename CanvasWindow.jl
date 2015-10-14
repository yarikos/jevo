#
# This module creates a platform independent window with a canvas inside. It
# uses Tk and Cairo libraries for that. Has an ability to draw a color pixels
# on a canvas. Uses RGB color format for drawing.
#
# Usage:
#   using CanvasWindow
#   ...
#   win = CanvasWindow.create(100, 100, "Window title")
#   CanvasWindow.dot(win, 10, 10, 1, 0, 0)  # R=1, G=0, B=0
#   CanvasWindow.dot(win, 20, 20, 11197883) # R=AA,G=DD,B=BB
#   CanvasWindow.destroy(win)
#
# @author DeadbraiN
#
module CanvasWindow
  import Base.Graphics
  import Cairo
  import Tk

  export Window
  export create
  export dot
  export update
  export destroy

  #
  # Data type, which contain one window related data: Canvas, Context,...
  # Is used in all public methods as a canvas for drawing.
  #
  type Window
    win::Tk.Tk_Toplevel
    canvas::Tk.Canvas
    context::Cairo.CairoContext
  end
  
  #
  # Creates window and shows it on the screen. Returns window related 
  # data type, which is used in all public methods od current module.
  # @param width Window width in pixels
  # @param height Window height in pixels
  # @param title Window title
  # @return Window object
  #
  function create(width::Integer, height::Integer, title::ASCIIString = "")
    win = Tk.Toplevel(title, width, height)
    c   = Tk.Canvas(win)
    Tk.pack(c, expand=true, fill="both")
    ctx = Base.Graphics.getgc(c)

    #
    # TODO: check if we need this line
    #
    #set_coords(ctx, 0, 0, 400, 200, 0, 399, 0, 199)
    Tk.set_antialias(ctx, 1)
    Tk.set_line_width(ctx, 1)
    #
    # TODO: background color should be taken from config
    #
    Tk.set_source_rgb(ctx, 0, 0, 0)
    Tk.paint(ctx)

    Window(win, c, ctx)
  end
  #
  # Draws one dot (point) on the canvas with specified color
  # @param win Windows type
  # @param x X coordinate of the point
  # @param y Y coordinate of the point
  # @param r Red part of RGB
  # @param g Green part of RGB
  # @param b Blue part of RGB
  #
  function dot(win::Window, x::Int, y::Int, r::Int, g::Int, b::Int)
    Tk.set_source_rgb(win.context, r, g, b)
    Tk.move_to(win.context, x, y)
    Tk.line_to(win.context, x+1, y)
    Tk.stroke(win.context)
  end
  #
  # Draws one dot (point) on the canvas with specified color
  # @param win Windows type
  # @param x X coordinate of the point
  # @param y Y coordinate of the point
  # @param color Color of the dot. We use only first three bytes (24bits)
  #
  function dot(win::Window, x::Int, y::Int, color::Int32)
    Tk.set_source_rgb(win.context, color >> 16, (color >> 8) & 0x0000ff, color & 0x0000ff)
    Tk.move_to(win.context, x, y)
    Tk.line_to(win.context, x+1, y)
    Tk.stroke(win.context)
  end
  #
  # Updates the canvas. It's not nessesary to update it after
  # every new dot. It's better to update it after several dots
  # are drown.
  # @param win Current window
  #
  function update(win::Window)
    Tk.reveal(win.canvas)
    Tk.update()
  end
  # TODO: i have to check if i need to destroy context and canvas
  # Destroys specified windows
  # @param win Windows to destroy
  #
  function destroy(win::Window)
  	Tk.destroy(win.win)
  end
end