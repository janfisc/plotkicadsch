open Kicadsch.Sigs

type diff_colors = {old_ver: string; new_ver: string; fg: string; bg: string}
module type Colors = sig
  val colors:diff_colors option
end
module type SvgP = sig
  include Painter
  val write: ?op:bool -> t -> string
end

module Make (C: Colors): SvgP =
  struct
    open Tyxml.Svg
    let colors =
      let default_colors = {old_ver="#FF0000"; new_ver="#00FF00"; fg="#000000"; bg="#FFFFFF"} in
      match C.colors with
      | Some c -> c
      | None -> default_colors
    type content = [ `Polyline | `Text | `Svg | `Rect | `Circle |`Path | `Image ]
    type dim = int*int
    type t =  { d: dim  ; c : content elt list} [@@inline]

let style_attr_of_style = function
  | Italic -> [a_font_style "italic"]
  | Bold -> [a_font_weight "bold"]
  | BoldItalic -> [a_font_style "italic"; a_font_weight "bold"]
  | NoStyle -> []

let anchor_attr_of_justify justif =
      a_text_anchor (match justif with
      | J_left -> `Start
      | J_center -> `Middle
      | J_right -> `End
      | J_bottom -> `End
      | J_top -> `Start)

let color_of_kolor k =
  let cstring = match k with
  | NoColor -> "none"
  | Black -> colors.fg
  | Red ->  colors.old_ver
  | Green -> colors.new_ver
  | Blue -> "#0000CD"
  | Brown -> "#800000"
  in `Color (cstring, None)

(** SVG coord type conversion from int **)
let coord_of_int x = float_of_int x, None

let paint_text ?(kolor=Black) t (o:orientation) (Coord (x,y)) (Size size) justif styl ({c; _} as ctxt) =
  let size_in = Printf.sprintf "%f"  (float_of_int size) and
      j = anchor_attr_of_justify justif and
      s = style_attr_of_style styl and
      x_c = float_of_int x and
      y_c = float_of_int y and
      angle = match o with
      | Orient_H -> 0.
      | Orient_V -> (-90.) in
  let orient = (angle,None), Some(x_c,y_c)
  in
  let color = color_of_kolor kolor in  { ctxt with c =
  (text ~a:([a_x_list [coord_of_int x] ; a_y_list [coord_of_int y] ; a_font_size size_in; j; a_transform[`Rotate orient]; a_fill color]@s) [pcdata t]) :: c}

let paint_line ?(kolor=Black) ?(width=(Size 2)) (Coord (x1, y1)) (Coord (x2, y2)) ({c; _} as ctxt) =
  let x1_in = float_of_int x1 in
  let y1_in = float_of_int y1 in
  let x2_in = float_of_int x2 in
  let y2_in = float_of_int y2 in
  let Size width = width in
  let fwidth = (float_of_int width) *. 5. in { ctxt with c =
  (polyline ~a:([a_points [(x1_in, y1_in); (x2_in, y2_in) ]; a_stroke_width (fwidth, Some `Px); a_stroke ( color_of_kolor kolor) ]) []) :: c}

let paint_rect ?(fill=NoColor) (Coord(x, y)) (Coord (dim_x, dim_y)) ({c;_ } as ctxt) = {ctxt with c =
  (rect ~a:[ a_x (coord_of_int x); a_y (coord_of_int y); a_width (coord_of_int dim_x); a_height (coord_of_int dim_y);a_fill (color_of_kolor fill); a_stroke_width (5., Some `Px); a_stroke (color_of_kolor Black)] []) :: c}

let paint_circle ?(kolor=Black) ?(fill=NoColor) (Coord(x, y)) radius ({c; _ } as ctxt) ={ctxt with c =
  (circle ~a:[a_r (coord_of_int radius); a_cx (coord_of_int x); a_cy (coord_of_int y); a_fill (color_of_kolor fill); a_stroke_width (10., Some `Px); a_stroke (color_of_kolor kolor) ] []) :: c}

let paint_arc ?(kolor=Black) ?(fill=NoColor) (Coord (x, y)) (Coord(x1, y1)) (Coord (x2, y2)) radius ({c; _} as ctxt) =
  (* not sure how this thing behaves. This setup seems to work *)
  let sweepflag = if (x1-x)*(y2-y)>(x2-x)*(y1-y) then 1 else 0 in
  {ctxt with c =
  ( path ~a:[a_d (Printf.sprintf "M%d,%d A%d,%d 0 0,%d %d,%d" x1 y1 radius radius sweepflag x2 y2); a_fill (color_of_kolor fill); a_stroke_width (10., Some`Px); a_stroke (color_of_kolor kolor)] []
  ) :: c}

let get_png_dims b =
  if Buffer.sub b 1 3 = "PNG" then begin
    let belong str =
      int_of_char str.[0] lsl 24 +
      int_of_char str.[1] lsl 16 +
      int_of_char str.[2] lsl 8 +
      int_of_char str.[3] in
    let w = belong (Buffer.sub b 16 4) in
    let h = belong (Buffer.sub b 20 4) in
    (w,h)
  end
  else
    (0,0)

let paint_image (Coord (x, y)) scale b ({c; _} as ctxt) =
  let s = scale /. 0.3 in
  let w, h = get_png_dims b in
  {ctxt with c = (image ~a:[
       a_x ((float(x) -. float(w/2)*.s), None);
       a_y ((float(y)-.float(h/2)*.s),None);
       a_height (float(h)*.s, None);
       a_width (float(w)*.s, None);
       a_xlink_href @@ "data:image/png;base64," ^ (B64.encode (Buffer.contents b))] [])
  :: c }

let get_context () = {d=(0,0) ; c=[]}

let set_canevas_size x y ctxt = {ctxt with d = (x,y)}

let write ?(op=true) {d= (x,y); c}  =
  let fx = float x in
  let fy = float y in
  let o = (if op then  1.0 else 0.8) in
  let opacity = a_style @@ Printf.sprintf "stroke-opacity:%f;fill-opacity:%f;" o o  in
  let svg_doc = svg  ~a:[a_width (fx *. 0.00254, Some `Cm); a_height (fy *. 0.00254, Some `Cm); a_viewBox (0.,0., float x, float y); a_font_family "Verdana, sans-serif";opacity] @@ (rect ~a:[a_fill (`Color ("#FFFFFF", None)); a_width (coord_of_int x); a_height (coord_of_int y)] [])::c in
  Format.asprintf "%a" (Tyxml.Svg.pp ()) svg_doc
  end
