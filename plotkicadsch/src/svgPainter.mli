open Kicadsch.Sigs
type diff_colors = {old_ver: string; new_ver: string; fg: string; bg: string}

module type SvgP = sig
  include Painter
  val write: ?op:bool -> t -> string
end

module type Colors = sig
  val colors:diff_colors option
end

module Make (C: Colors ): SvgP
