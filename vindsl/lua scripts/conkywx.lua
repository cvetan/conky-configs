
-- Description at the end of the file - constnts here ------ {{{

require 'cairo'
require 'imlib2'
-- require 'lfs'

-- Constants ---------------------------------------------------------
local PI = 3.14159265358979323846
local TORADIANS = 3.14159265358979323846/180
local font = "Mono"
local Default_Font_Name = 'Mono'
-- local Default_Font_Name = 'SansSerif'
local Default_Font_Style= 'NORMAL'
local Default_Font_Size = 12
local Global_Font_Size

-- for animated clock
local MAX = 60 -- A conky update interval of 0.1

local next    = next
local sin     = math.sin
local cos     = math.cos
local abs     = math.abs
local random  = math.random
local floor   = math.floor
local tconcat = table.concat
local tinsert = table.insert
local sprintf = string.format
local slower  = string.lower
local tonum   = tonumber

package.path = tconcat({"./lib/?.lua;",package.path})

----------------------------------------------------------------------
-- Define colours here in hex format
-- Excellent reference for colour names and their hex values visit
-- http://www.imagemagick.org/script/color.php
local Red            = 0xFF0000
-- local VioletRed      = 0xCD3278
local Blue           = 0x0000ff
-- local NBlue          = 0x33fff5
local RoyalBlue      = 0x4169E1
local NavyBlue		 = 0x000080
local MidnightBlue	 = 0x191970
local Cyan			 = 0x00ffff
local Black          = 0x000000
local White          = 0xFFFFFF
local Yellow         = 0xFFFF00
-- local NYellow        = 0xFFF533
local Magenta        = 0xff00ff
-- local Purple         = 0x8B5Aff
local Orchid1        = 0xFF83FA
local Gold           = 0xFFD700
local DarkGold       = 0xCD950C
local Orange         = 0xFF3300
-- local Orange2        = 0xdd6600
local Orange3        = 0xFF5500
-- local Orange4		 = 0x8B5A00
-- local Brown          = 0xA52A2A
local SaddleBrown    = 0x8B4513
-- local Grey69         = 0xB0B0B0
-- local Grey72         = 0xB8B8B8
local Grey81         = 0xd0d0d0
local Lime           = 0x00FF00
-- local LimeGreen      = 0x32CD32
local DarkLime       = 0x32B000
-- local Green          = 0x009000
-- local Green3         = 0x00CD00
-- local DarkOlive      = 0xBCEE68
-- local Tan1           = 0xFFA54F


-- -- alarm value only effective if bar_led_effect is true
local bar_alarm_value      = 90
-- --alarm colour is also the end colour for gradient colour - so leave it enabled
local bar_alarm_colour     = {Red,0.80}
local bar_fg_colour        = {Lime,0.90}
local bar_mid_colour       = {{0.38,Yellow,0.90}}
local bar_bg_colour        = {White,0.25}

-- -- bargraph values not likely to be changed
local bar_max_value        = 100 ---- % value of the expected max measure
local bar_angle_value      = 90  ---- you can vertical bars with 0 angle

-- local user_home = os.getenv("HOME")
-- local pre_exec_status

local cr = nil

-- End Constants -----------------------------------------------}}}---
local function wxsplit(string,delimiter,wxnum)
	local result = { }
	local from  = 1
	local self = tconcat({string,''})
	self = self:match( "^%s*(.-)%s*$" )
	local delim_from, delim_to = string.find( self, delimiter, 1  )
	if delim_to then
		if wxnum ~= 1 then
			while delim_from do
				result[#result+1]=string.sub( self, from, delim_from-1 )
				from  = delim_to + 1
				delim_from, delim_to = string.find( self, delimiter, from  )
			end
			result[#result+1]=string.sub( self, from )
		else
			if delimiter == "°" then acase = 2 else acase = 1 end
			result[#result+1]=string.sub( self, 1, delim_to-acase )
			result[#result+1]=string.sub( self, delim_from+1, -1  )
		end
	else
		result[#result+1]=string.sub( self, 1 )
	end
	return result
end

local function ExecInfo(p)
	local f1
	if p.cmd then
		f1=io.popen(tconcat({p.cmd,' 2>&1'}))
	elseif p.rfile then
		f1=io.open(p.rfile,'r')
	elseif p.wfile and p.wtext then
		f1=io.open(p.wfile,'w')
		if f1 then
			if type(p.wtext) == 'table' then
				for d = 1, #p.wtext
				do
					f1:write(p.wtext[d]..'\n')
				end
			else
				f1:write(p.wtext)
			end
			f1:close()
		end
		return nil
	end
	if f1 then
		local rinfo = f1:read("*a")
		f1:close()
		rinfo = rinfo:match( "^%s*(.-)%s*$" )
		return rinfo
	end
end

local function firstToUpper(str)
	if str then return (str:gsub("^%l", string.upper)) end
	return ''
end

local function FileStat(t)
	local outstat = ExecInfo({ cmd = tconcat({'stat -c%s ',t.ifile}) })
	local instat = ExecInfo({ rfile = t.ofile })
	if instat then
		if tonum(instat) ~= tonum(outstat) then
			ExecInfo({ wfile = t.ofile, wtext = outstat })
			return nil
		else
			return true
		end
	else
		ExecInfo({ wfile = t.ofile, wtext = outstat })
		return nil
	end
end

local function FileExists(fname)
	local f = ExecInfo({ cmd = tconcat({ 'if [ -e "',fname,'" ]; then echo "true"; fi'})})
	if f == 'true' then return true else return nil end
end

local function DirExists(dpath)
	local f = ExecInfo({ cmd = tconcat({ 'if [ -d "',dpath,'" ]; then echo "true"; fi'})})
	if f == 'true' then return true else return nil end
end

-- function script_path()
-- 	local mypath = ExecInfo({ cmd = '"$( cd "." && pwd )"'}):match( ":%s*(.-):" )
-- 	local str = debug.getinfo(2, "S").source:sub(2)
-- 	return tconcat({ mypath,str:match("(/.-)/") })
-- end
-- package.path = tconcat({script_path(),"/?.lua;",package.path})
-- print(package.path)

local function set_font(p)		----{{{
	--- paramvir
	cairo_restore(cr)

	local fontname
	local fontsize
	local fontstyle
	local fontslant
	local fontt={}
	local function parse_ft(p)
		if p[1] == "style" then
			if p[2] ~= "" then
				return( string.upper(p[2]))
			else
				return('NORMAL')
			end
		elseif p[1] == "size" then
			if p[2] then
				return(tonum(p[2]))
			else
				return(Default_Font_Size)
			end
		end
	end
	if p then
		fontt = wxsplit(p,":")
		for c,d in ipairs(fontt) do
			if d~="" then
				if d:match("=") then
					local fst=d:wxsplit("=")
					local fontw = parse_ft(fst)
					if type(fontw) == 'string' then
						fontstyle = fontw
					else
						fontsize = fontw
					end
					-- print(fontsize)
				else
					d=string.upper(d)
					if d=='BOLD' or d=='NORMAL' then
						fontstyle = d
					elseif d=='ITALIC' then
						fontslant = d
					else
						if tonum(d) then
							fontsize = d
						else
							fontname = d
						end
					end
				end
			end
		end
	end
	-- print(tonum(CAIRO_FONT_SLANT_ITALIC))
	-- if not fontname  or tonum(fontname) then
	fontname  = fontname  or Default_Font_Name
	fontstyle = fontstyle or Default_Font_Style
	fontsize  = fontsize  or Default_Font_Size
	fontslant = fontslant or 0

	if fontstyle == 'BOLD'   then fontstyle = 1 else fontstyle = 0 end -- 0 is normal
	if fontslant == 'ITALIC' then fontslant = 1 else fontslant = 0 end -- 0 is normal

	Global_Font_Size = fontsize
	cairo_set_font_size(cr, fontsize)
	cairo_select_font_face(cr, fontname, fontslant, fontstyle);

	cairo_save(cr)
end		------ }}}



-- ----------------------------------------------------------------------
function conky_startup()
-- by paramvir 2015 conkywx
	ExecInfo({
		wfile = tconcat({'/tmp/conkywx_tmp_',conky_config:match("([^/]+)$")}),
		wtext = conky_info.update_interval,
	})
	conky_set_update_interval(0.1)
	return ''
end

function conky_top_name(...)
-- by paramvir 2015 conkywx
	local p = {...}
	if p[1] then
		local tn1 = tconcat(p,' ')
		return conky_parse(tn1):match("(%w+)%s*") or ''
	end
	return ''
end

function conky_if_running(...)
-- by paramvir 2015 conkywx
	local p = {...}
	if p[1] then
		local pdata = tconcat(p,' ')
		pdata = tconcat({'pidof ',pdata})
		local if_status = ExecInfo({ cmd = pdata })
		if if_status ~= '' then if_status = '1' else if_status = '-1' end
		return if_status
	else
		error("\nError :(\nif_running expects argument(s)")
	end
end


local pretable  = {}
local counter = 0
function conky_pre_exec(...)
-- by paramvir 2015 conkywx
	local p = {...}
	local v1 = {}
	if p[1] then
		local pdata = tconcat(p,' ')
		if #pretable > 0 then
			for k = 1, #pretable do
				v1 = wxsplit(pretable[k],' ::: ')
				if v1[1] == pdata then
					return v1[2]
				end
			end
		end
		if counter == 0 then
			pretable[#pretable + 1] = pdata
			for k = 1, #pretable do
				local pred = ExecInfo({ cmd = pretable[k] })
				pred = pred or ''
				pretable[k] = tconcat({pretable[k],' ::: ',pred})
			end
		end
		return ''
	else
		error("\nError :(\npre_exec expects argument(s)")
	end
	counter = counter + 1
end


function conky_sysinfo(...)
-- by paramvir 2015 conkywx
	local p = {...}
	local retval
	if p[1] then
		local opt
		if slower(p[1]) == '-f' then opt = p[2] else opt = p[1] end
		if opt:match('[/]') then
			local sys_status = ExecInfo({ rfile = opt })
			if not sys_status then
				error("\nError :(\nsysinfo wrong arguments")
			else
				if opt:match('fan') then
					retval = sys_status
				elseif slower(p[1]) == '-f' then
					retval = sprintf("%03d",((tonum(sys_status)/1000) * 1.8) + 32)
				else
					retval = tonum(sys_status)/1000
				end
			end
		else
			local sensdata = {}
			local to_run = 'sensors'
			local pu
			local pu2 = {
				fan1 = 'fan1',
				fan2 = 'fan2',
				fan3 = 'fan3',
				fan4 = 'fan4',
				cpu1 = 'Core 0:',
				cpu2 = 'Core 1:',
				cpu3 = 'Core 2:',
				cpu4 = 'Core 3:',
				cpu5 = 'Core 4:',
				cpu6 = 'Core 5:',
				cpu7 = 'Core 6:',
				cpu8 = 'Core 7:',
				pch  = 'PCH_CHIP',
			}
			if p[1] == '-f' then
				to_run = tconcat({to_run,' -f'})
				if p[2] then pu = slower(p[2])
				else error("\nError :(\nsysinfo2 expects an argument cpu1 or fan2 etc") end
			else
				if p[1] then pu = slower(p[1])
				else error("\nError :(\nsysinfo2 expects an argument cpu1 or fan2 etc") end
			end
			local line = ExecInfo({ cmd = to_run })
			sensdata = wxsplit(line,'\n')
			for k = 1, #sensdata do
				if pu:match('fan') then
					if sensdata[k]:match(pu) then
						retval=sensdata[k]:match('^.*:%s*(%d+)' )
					end
				else
					if sensdata[k]:match(pu2[pu]) then
						retval=sensdata[k]:match('^.*:%s*+(%d+)')
					end
				end
			end
		end
	else
		error("\nError :(\nsysinfo expects argument(s)")
	end
	return retval or ''
end

local pacupdate = 0
function conky_pacman_update()
--[[
	Copyright (c) 2013-2015 Paramvir

	to enable on systemd systems use cronie is part of the Arch base install
	sudo systemctl enable cronie.service
	to enable the cron job
	type sudo crontab -e and add following to run every 3 hours
	0 */3 * * * /path_to_file/pacman_update.sh
	To see in the conky desktop:
	Place this line above the TEXT area with correct path
	${color3}Pkgs:${alignr}${color1}${lua pacman_update}${font}
--]]

	local upd1 = tonum(conky_parse("${updates}"))
	if (upd1 % 60) == 0 or pacupdate == 0 then
		local pacdata = {}
		local line = ExecInfo({ cmd = 'pacman -Qu' })
		if line then pacdata = wxsplit(line,'\n') end
		local to_ignore = 0
		local to_update = 0

		if pacdata[1] then
			to_update = #pacdata
			for d = 1, #pacdata do
				if pacdata[d]:find('%[ignored%]') then
					to_ignore = to_ignore + 1
					to_update = to_update - 1
				end
			end
		end

		if to_update == 0 then
			pacupdate = 'System up-to-date'
		else
			pacupdate = tconcat({to_update,' new | ',to_ignore,' ignored'})
		end
	end
	return pacupdate or ''
end


local function strip_ext_codes( str )
	local s = ""
	for i = 1, str:len() do
		if str:byte(i) >= 32 and str:byte(i) <= 126 then
			s = tconcat({s,str:sub(i,i)})
		end
	end
	return s
end

local function to_rgba(t)
	return ((t[1] / 0x10000) % 0x100) / 255.,
		((t[1] / 0x100) % 0x100) / 255., (t[1] % 0x100) / 255., t[2]
end

local function make_bezel(p)
	cairo_restore(cr)
	local b_rad = p.bezel_size/1.24
	local s_rad = b_rad/5
	local pat = cairo_pattern_create_radial(p.px-70,p.py-39,s_rad,p.px-24,p.py-24, b_rad)
	cairo_pattern_add_color_stop_rgba(pat, 0, 1, 1, 1, 1)
	cairo_pattern_add_color_stop_rgba(pat, 1, 0, 0, 0, 1)
	cairo_set_source(cr, pat)
	cairo_arc(cr, p.px, p.py, b_rad/1.6669, 0, 2 * PI)
	cairo_fill(cr)
	local pat = cairo_pattern_create_radial(p.px+70,p.py+39,s_rad,p.px+24,p.py+24, b_rad)
	cairo_pattern_add_color_stop_rgba(pat, 0, 1, 1, 1, 1)
	cairo_pattern_add_color_stop_rgba(pat, 1, 0, 0, 0, 1)
	cairo_set_source(cr, pat)
	cairo_arc(cr, p.px, p.py, b_rad/1.75, 0, 2 * PI)
	cairo_fill(cr)
	cairo_pattern_destroy(pat)
	cairo_save(cr)
end

local function instrument_sqr(p)
-- instrument_sqr by paramvir 2014
	cairo_restore(cr)
	--------------------------------------
	-- local rout1 = (routA*.478)
	-- print(p.routI)
	local wx=p.wx
	local wy=p.wy
	local rout=(p.routI*.45)
	local rout1 = (p.routI*.5)
	local crtlx=p.wx-rout1
	local crtly=p.wy-rout1
	local crbxy=rout1*2
	local main_colour={0x404040,1}
	-----------------------------------------
	local cnr=25
	local w=crbxy+crtlx
	local h=crbxy+crtly
	-----------------------------------------
	cairo_move_to(cr, crtlx, crtly+cnr)
	cairo_line_to(cr, crtlx, h-cnr)
	cairo_curve_to(cr,crtlx,h,crtlx,h,crtlx+cnr,h)
	cairo_line_to(cr, w-cnr, h)
	cairo_curve_to(cr,w,h,w,h,w,h-cnr)
	cairo_line_to(cr, w, crtly+cnr)
	cairo_curve_to(cr,w,crtly,w,crtly,w-cnr,crtly)
	cairo_line_to(cr, crtlx+cnr, crtly)
	cairo_curve_to(cr,crtlx,crtly,crtlx,crtly,crtlx,crtly+cnr)
	cairo_arc (cr,wx,wy,rout,0,TORADIANS*360)
	cairo_set_source_rgba (cr,to_rgba(main_colour))
	cairo_fill(cr);
	-----------------------------------------
	----- panel fitting background
	local bolthd=(rout1*.15)
	local xymove=(rout1*.2)
	local scrhdx=(crtlx+xymove)
	local scrhdy=(crtly+xymove)
	local blthdmv=(xymove*0.3)
	cairo_arc (cr,crtlx+xymove,crtly+xymove,bolthd,TORADIANS,0)
	cairo_set_source_rgba (cr,0.35,0.35,0.35,1)
	cairo_fill(cr);
	cairo_set_line_width(cr, xymove*.15)
	cairo_set_source_rgba (cr,0.1,0.1,0.1,1)
	cairo_arc (cr,crtlx+xymove,crtly+xymove,bolthd,TORADIANS,0)
	cairo_stroke(cr);
	cairo_set_source_rgba (cr,0.7,0.7,0.7,1)
	cairo_move_to(cr, scrhdx-blthdmv, scrhdy-blthdmv)
	cairo_line_to(cr, scrhdx+blthdmv, scrhdy+blthdmv)
	cairo_move_to(cr, scrhdx+blthdmv, scrhdy-blthdmv)
	cairo_line_to(cr, scrhdx-blthdmv, scrhdy+blthdmv)
	cairo_stroke(cr);
	cairo_arc (cr,w-xymove,crtly+xymove,bolthd,TORADIANS,0)
	cairo_set_source_rgba (cr,0.35,0.35,0.35,1)
	cairo_fill(cr);
	cairo_set_line_width(cr, xymove*.15)
	cairo_set_source_rgba (cr,0.1,0.1,0.1,1)
	cairo_arc (cr,w-xymove,crtly+xymove,bolthd,TORADIANS,0)
	cairo_stroke(cr);
	cairo_set_source_rgba (cr,0.7,0.7,0.7,1)
	cairo_move_to(cr, w-xymove-blthdmv, scrhdy-blthdmv)
	cairo_line_to(cr, w-xymove+blthdmv, scrhdy+blthdmv)
	cairo_move_to(cr, w-xymove+blthdmv, scrhdy-blthdmv)
	cairo_line_to(cr, w-xymove-blthdmv, scrhdy+blthdmv)
	cairo_stroke(cr);
	cairo_arc (cr,w-xymove,h-xymove,bolthd,TORADIANS,0)
	cairo_set_source_rgba (cr,0.35,0.35,0.35,1)
	cairo_fill(cr);
	cairo_set_line_width(cr, xymove*.15)
	cairo_set_source_rgba (cr,0.1,0.1,0.1,1)
	cairo_arc (cr,w-xymove,h-xymove,bolthd,TORADIANS,0)
	cairo_stroke(cr);
	cairo_set_source_rgba (cr,0.7,0.7,0.7,1)
	cairo_move_to(cr, w-xymove-blthdmv, h-xymove-blthdmv)
	cairo_line_to(cr, w-xymove+blthdmv, h-xymove+blthdmv)
	cairo_move_to(cr, w-xymove+blthdmv, h-xymove-blthdmv)
	cairo_line_to(cr, w-xymove-blthdmv, h-xymove+blthdmv)
	cairo_stroke(cr);
	cairo_arc (cr,crtlx+xymove,h-xymove,bolthd,TORADIANS,0)
	cairo_set_source_rgba (cr,0.35,0.35,0.35,1)
	cairo_fill(cr);
	cairo_set_line_width(cr, xymove*.15)
	cairo_set_source_rgba (cr,0.1,0.1,0.1,1)
	cairo_arc (cr,crtlx+xymove,h-xymove,bolthd,TORADIANS,0)
	cairo_stroke(cr);
	cairo_set_source_rgba (cr,0.7,0.7,0.7,1)
	cairo_move_to(cr, scrhdx-blthdmv, h-xymove-blthdmv)
	cairo_line_to(cr, scrhdx+blthdmv, h-xymove+blthdmv)
	cairo_move_to(cr, scrhdx+blthdmv, h-xymove-blthdmv)
	cairo_line_to(cr, scrhdx-blthdmv, h-xymove+blthdmv)
	cairo_stroke(cr);
	-----------------------------------------
	cairo_save(cr)

end

----------------------------------------------------------------------
local function put_image(p)		------------ {{{

	local bgcolour11 	= "0xFF0030:1"
	local bgcolour11 = wxsplit(bgcolour11,":")

	local night_effect = p.night or 0
	local scale = p.scale or 1

	local file_tp
	local opt2
	if p.ip then
		file_tp = tconcat({p.ip,p.file})
		opt2 = "1"
	else
		file_tp = p.file
	end
	local image = cairo_image_surface_create_from_png (file_tp);
	local w = cairo_image_surface_get_width (image);
	local h = cairo_image_surface_get_height (image);
	cairo_save(cr)

	cairo_translate (cr, p.x, p.y);
	if p.rotate then cairo_rotate(cr, p.theta) end
	if not opt2 then
		nw = ((scale*100)/w)
		nh = ((scale*100)/h)
		cairo_scale  (cr, nw, nh);
	else
		cairo_scale  (cr, scale, scale);
	end

	cairo_translate (cr, -0.5*w, -0.5*h);

	cairo_set_source_surface (cr, image, 0, 0)

	if p.dial_colour then
		-- local pcol1 = Yellow..":1"
		-- local pcol = wxsplit(pcol1,":")
		-- print(dial_colour)
		cairo_set_source_rgba(cr, to_rgba(p.dial_colour))
		cairo_set_operator (cr, CAIRO_OPERATOR_SOURCE)
	end

	cairo_mask_surface (cr, image, 0, 0);
	cairo_surface_destroy (image);
	cairo_restore(cr)
end		------------ }}}

----------------------------------------------------------------------
local function circlewriting2(text, radi, horiz, verti, start, finish)		------------ {{{
	cairo_restore(cr)
	local inum=string.len(text)
	local deg=(finish-start)/(inum-1)
	local degrads=TORADIANS
	local textcut=string.gsub(text, ".", "%1|")
	texttable = wxsplit(textcut,"|")
	for i=1,inum do
		interval=(degrads*(start+(deg*(i-1))))
		txs=0+radi*(sin(interval))
		tys=0-radi*(cos(interval))
		cairo_move_to (cr, txs+horiz, tys+verti);
		cairo_rotate (cr, interval)
		cairo_show_text (cr, (texttable[i]))
		cairo_stroke (cr)
		cairo_rotate (cr, -interval)
	end
	cairo_save(cr)
end--circlewriting		------------ }}}


local function trim(p)
	local string_match = string.match
	-- local self = self .. ""
	-- self = self:match( "^%s*(.-)%s*$" )
	return string_match(p.text, "^%s*(.-)%s*$") or ""
	-- return self or ""
end
----------------------------------------------------------------------
local function make_txt(p)		------------ {{{
	-- pre-declare font, size, cairo_select_font_face at calling function head
	cairo_restore(cr)
	local align = p.align or "c"
	local mtxt = trim({text=p.text,})
	local extents=cairo_text_extents_t:create()
	if align == "r" then -- make right align
		cairo_text_extents(cr,mtxt,extents)
		cairo_move_to (cr,p.px-extents.width,p.py)
	elseif align == "c" then -- make centered
		cairo_text_extents(cr,mtxt,extents)
		cairo_move_to (cr,p.px-(extents.width/2),p.py)
	elseif align == "l" then -- keep left aligned
		cairo_move_to (cr,p.px,p.py)
	end
	if p.icolour then
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
	end
	cairo_show_text (cr,mtxt)
	cairo_stroke (cr)
	cairo_save(cr)
end		------------ }}}


----------------------------------------------------------------------
local function make_scale_txt2(p)		------------ {{{
	-- pre-declare font, size, cairo_select_font_face at calling function head
	cairo_restore(cr)

	local arc=TORADIANS*(p.startscale+(p.i*(p.endscale/p.maxscale)))
	local sin_arc=sin(arc)
	local cos_arc=cos(arc)

	if not p.ifact then
		p.ifact=1
	end

	if p.trout then
		if p.i % p.ifact == 0 then
			local ppx2=(0+p.trout*sin_arc)
			local ppy2=(0-p.trout*cos_arc)
			local extents=cairo_text_extents_t:create()
			cairo_text_extents(cr,p.text,extents)
			local width=extents.width
			local height=extents.height
			if not p.squeeze then  -- do the squeeze if nil
				cairo_move_to (cr,p.xval+ppx2-(width/2),p.yval+(ppy2/1.02)+(height/2))
			else
				cairo_move_to (cr,p.xval+ppx2-(width/2),p.yval+ppy2+(height/2))
			end
			cairo_show_text (cr,p.text)
		end
	end
	if not p.dotext then  -- output marks if nil
		local ppx1=(0+p.rout*sin_arc)
		local ppy1=(0-p.rout*cos_arc)
		local pix1=(0+p.rin*sin_arc)
		local piy1=(0-p.rin*cos_arc)
		cairo_move_to (cr,p.xval+ppx1,p.yval+ppy1)
		cairo_line_to (cr,p.xval+pix1,p.yval+piy1)
	end

	cairo_stroke (cr)
	cairo_save(cr)
end		------------ }}}

local function get_points(startpt,degval,degfact,sizefact,opsign)
	-- startpt,degval,degfactor,sizefactor
	-- local startpt 	= p.spt
	-- local degval	= p.dval
	-- local degfact	= p.dfact		or 0
	-- local sizefact	= p.sfact
	if opsign == 1 then sizefact = (sizefact * -1) end
	local arc=TORADIANS*(startpt+degval+degfact)
	local pointx=0 + sizefact*(sin(arc))
	local pointy=0 - sizefact*(cos(arc))
	return pointx, pointy

end

local function choose_indicator(p)
	-- indicator functions by paramvir 2014

	local chin = p.ch_indi

	if p.ch_indi < 0 then
		p.scale = p.scale + 180
		chin = chin * -1
	end

	local function make_indicator01(p) ---- {{{
		cairo_restore(cr)
		local rout1=p.rout1*0.78
		local px,py=p.px,p.py
		local scale = p.scale
		local scale = scale-12
		local ppx1,ppy1=get_points(p.startval,scale,0,rout1)
		local ppx2,ppy2=get_points(p.startval,scale,-340,rout1)
		local ppx3,ppy3=get_points(p.startval,scale,-170,(rout1*0.2),1)
		local ppx4,ppy4=get_points(p.startval,scale,-350,(rout1*0.98))
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_move_to (cr,px+ppx3,py+ppy3)
		cairo_line_to (cr,px+ppx1,py+ppy1)
		cairo_line_to (cr,px+ppx2,py+ppy2)
		cairo_line_to (cr,px+ppx3,py+ppy3)
		cairo_arc (cr,px+ppx4,py+ppy4,(rout1*0.17),TORADIANS,0)
		cairo_fill (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator02(p) ---- {{{
		cairo_restore(cr)
		local rout1=p.rout1
		local scale=p.scale
		local center_thickness = p.cthick or rout1*0.14
		local center_dot = center_thickness*0.6
		--------------------------------
		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local pilx,pily=get_points(p.startval,scale,-90,center_thickness)
		local pirx,piry=get_points(p.startval,scale,90,center_thickness)
		--------------------------------
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_arc (cr,p.px,p.py,center_thickness,TORADIANS,0)
		cairo_move_to (cr,p.px+pilx,p.py+pily)
		cairo_line_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+pirx,p.py+piry)
		cairo_line_to (cr,p.px+pilx,p.py+pily)
		cairo_fill (cr)
		-----------------------------------
		cairo_set_source_rgba (cr,0,0,0,1)
		cairo_arc (cr,p.px,p.py,center_dot,TORADIANS,0)
		cairo_fill (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator03(p) ---- {{{
		cairo_restore(cr)
		local rout1=p.rout1
		local scale=p.scale+180
		local center_thickness = p.cthick or rout1*0.1
		local center_dot = center_thickness*0.7
		--------------------------------
		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local ppox,ppoy=get_points(p.startval,scale,180,rout1)
		--------------------------------
		-- rout2=rout1*0.15
		local pilx,pily=get_points(p.startval,scale,-90,center_thickness)
		local pirx,piry=get_points(p.startval,scale,90,center_thickness)
		--------------------------------
		cairo_move_to (cr,p.px+pilx,p.py+pily)
		cairo_line_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+pirx,p.py+piry)
		cairo_line_to (cr,p.px+pilx,p.py+pily)
		cairo_set_source_rgba (cr,to_rgba({0xffffff,1}))
		cairo_fill (cr)

		cairo_move_to (cr,p.px+pilx,p.py+pily)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_line_to (cr,p.px+pirx,p.py+piry)
		cairo_line_to (cr,p.px+pilx,p.py+pily)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_fill (cr)

		cairo_arc (cr,p.px,p.py,center_dot,TORADIANS,0)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_fill (cr)
		-- -- -----------------------------------
		-- black dot
		cairo_arc (cr,p.px,p.py,center_dot,TORADIANS,0)
		cairo_set_source_rgba (cr,0,0,0,1)
		cairo_fill (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator04(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale
		local center_thickness = p.cthick or rout1*0.04
		--------------------------------
		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*0.5))
		local ppx2,ppy2=get_points(p.startval,scale,-7,(rout1*0.81))
		local ppx3,ppy3=get_points(p.startval,scale,7,(rout1*0.81))
		--------------------------------
		cairo_set_line_width (cr,center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_line_to (cr,p.px+ppx3,p.py+ppy3)
		cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_line_to (cr,p.px+ppx3,p.py+ppy3)
		cairo_stroke(cr)
		local ppox1,ppoy1=get_points(p.startval,scale,180,(rout1*0.65))
		local arc1=TORADIANS*(p.startval+scale-150)
		local arc2=TORADIANS*(p.startval+scale-30)
		cairo_arc (cr,p.px+ppox1,p.py+ppoy1,(rout1/6.8),arc1,arc2)
		cairo_set_line_width (cr,center_thickness)
		cairo_stroke (cr)
		-----------------------------------
		cairo_set_source_rgba (cr,1,1,0,1)
		cairo_set_line_width (cr,center_thickness) -- center dot
		cairo_arc (cr,p.px,p.py,center_thickness,TORADIANS,0)
		cairo_stroke (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator05(p)
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale
		local center_thickness = p.cthick or rout1*0.04
		--------------------------------
		local ppx,ppy=get_points(p.startval,scale,0,rout1*.95)
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*0.8))
		local ppx2,ppy2=get_points(p.startval,scale,-10,(rout1*0.7))
		local ppx3,ppy3=get_points(p.startval,scale,10,(rout1*0.7))
		--------------------------------
		cairo_set_line_width (cr,center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		-- cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppx3,p.py+ppy3)
		-- cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_stroke(cr)
		cairo_set_line_width (cr,center_thickness)
		local ppox1,ppoy1=get_points(p.startval,scale,180,(rout1*0.65))
		local arc1=TORADIANS*(p.startval+scale-150)
		local arc2=TORADIANS*(p.startval+scale-30)
		cairo_arc (cr,p.px+ppox1,p.py+ppoy1,(rout1/6.8),arc1,arc2)
		local ppox2,ppoy2=get_points(p.startval,scale,180,(rout1*0.80))
		cairo_stroke (cr)
		cairo_arc (cr,p.px+ppox2,p.py+ppoy2,(rout1/6.8),arc1,arc2)
		cairo_stroke (cr)
		-----------------------------------
		cairo_set_source_rgba (cr,1,1,0,1)
		cairo_set_line_width (cr,center_thickness)
		cairo_arc (cr,p.px,p.py,center_thickness,TORADIANS,0)
		cairo_stroke (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator06(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale -- end angle, p.startval is start angle value
		local csize=p.csize

		local center_thickness = p.cthick or rout1*0.1
		local center_dot = rout1/6

		if p.chands == 1 then
			center_dot = rout1/12.5
		end


		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_arc(cr, p.px, p.py, center_dot, TORADIANS, 0)
		cairo_fill(cr)

		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*0.30))
		--------------------------------
		cairo_set_line_width (cr, center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_stroke(cr)
		-----------------------------------
		cairo_arc(cr,p.px,p.py, center_dot, TORADIANS, 0)
		cairo_fill(cr)
		cairo_set_source_rgba (cr,1,1,0,1)
		cairo_arc (cr,p.px,p.py,center_dot/2.5,TORADIANS,0)
		cairo_fill (cr)

		cairo_save(cr)
	end ---- }}}

	local function make_indicator07(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale -- end angle, p.startval is start angle value
		local csize=p.csize

		local center_thickness = p.cthick or rout1*0.1
		local center_dot = rout1/6

		if p.chands then
			center_dot = rout1/12.5
		end


		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_arc(cr, p.px, p.py, center_dot, TORADIANS, 0)
		cairo_fill(cr)

		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*0.30))
		--------------------------------
		cairo_set_line_width (cr, center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_stroke(cr)
		-----------------------------------
		cairo_set_source_rgba (cr,1,1,0,1)
		cairo_arc (cr,p.px,p.py,center_dot/2.5,TORADIANS,0)
		cairo_fill (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator08(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale
		local center_thickness = p.cthick or rout1*0.05
		local center_dot = rout1/6
		if p.chands then
			center_dot = rout1/12.5
		end
		--------------------------------
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_arc(cr, p.px, p.py, center_dot, TORADIANS, 0)
		cairo_fill(cr)
		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		-- local ppox,ppoy=get_points(p.startval,scale,180,(rout1*0.5))
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*0))
		-- local ppx2,ppy2=get_points(p.startval,scale,-7,(rout1*0.81))
		local ppx2,ppy2=get_points(p.startval,scale,-7.5,(rout1*0.81))
		local ppx3,ppy3=get_points(p.startval,scale,7.5,(rout1*0.81))
		--------------------------------
		cairo_set_line_width (cr,center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_line_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppx3,p.py+ppy3)
		-- cairo_line_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_fill(cr)
		-----------------------------------
		cairo_set_source_rgba (cr,1,1,0,1)
		cairo_set_line_width (cr,center_thickness) -- center dot
		cairo_arc (cr,p.px,p.py,center_thickness,TORADIANS,0)
		cairo_stroke (cr)
		cairo_save(cr)
	end ---- }}}

	local function make_indicator09(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale + 180
		local center_thickness = p.cthick or rout1*0.05
		local center_dot = rout1/6
		if p.chands then
			center_dot = rout1/12.5
		end
		--------------------------------
		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*-0.39))
		local ppx2,ppy2=get_points(p.startval,scale,-7.8,(rout1*0.81))
		local ppx3,ppy3=get_points(p.startval,scale,7.8,(rout1*0.81))
		--------------------------------
		cairo_set_line_width (cr,center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_line_to (cr,p.px+ppx3,p.py+ppy3)
		cairo_fill(cr)
		-----------------------------------
		cairo_save(cr)
	end ---- }}}

	local function make_indicator10(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale
		local center_thickness = p.cthick or rout1*0.05
		local center_dot = rout1/6
		if p.chands then
			center_dot = rout1/12.5
		end
		--------------------------------
		local ppx,ppy=get_points(p.startval,scale,0,rout1)
		local ppox,ppoy=get_points(p.startval,scale,180,(rout1*-1.1))
		local ppix,ppiy=get_points(p.startval,scale,180,(rout1*-0.5))
		local ppx2,ppy2=get_points(p.startval,scale,-9.9,(rout1*0.78))
		local ppx3,ppy3=get_points(p.startval,scale,9.9,(rout1*0.78))
		--------------------------------
		cairo_set_line_width (cr,center_thickness)
		cairo_set_line_cap  (cr, CAIRO_LINE_CAP_ROUND);
		cairo_move_to (cr,p.px+ppx,p.py+ppy)
		cairo_line_to (cr,p.px+ppox,p.py+ppoy)
		cairo_set_source_rgba (cr,to_rgba(p.icolour))
		cairo_stroke(cr)
		cairo_move_to (cr,p.px+ppx2,p.py+ppy2)
		cairo_line_to (cr,p.px+ppx3,p.py+ppy3)
		cairo_line_to (cr,p.px+ppix,p.py+ppiy)
		cairo_fill(cr)
		-----------------------------------
		cairo_save(cr)
	end ---- }}}

	local function make_indicator11(p) ---- {{{
		cairo_restore(cr)
		local sfact=1
		local rout1=p.rout1*sfact
		local scale=p.scale+90
		local center_thickness = p.cthick or rout1*0.05
		local center_dot = rout1/6
		if p.chands then
			center_dot = rout1/12.5
		end
		local fileN = tconcat({p.ip,'/lua_windvane/arrow-',p.arrow,'.png'})
		put_image({
			x      = p.px,
			y      = p.py,
			file   = fileN,
			scale  = p.rout1/50,
			theta  = scale * TORADIANS,
			dial_colour = p.icolour,
			rotate = true,
			})
		-----------------------------------
		cairo_save(cr)
	end ---- }}}

	if     chin ==  1 then make_indicator01(p)
	elseif chin ==  2 then make_indicator02(p)
	elseif chin ==  3 then make_indicator03(p)
	elseif chin ==  4 then make_indicator04(p)
	elseif chin ==  5 then make_indicator05(p)
	elseif chin ==  6 then make_indicator06(p)
	elseif chin ==  7 then make_indicator07(p)
	elseif chin ==  8 then make_indicator08(p)
	elseif chin ==  9 then make_indicator09(p)
	elseif chin == 10 then make_indicator10(p)
	elseif chin == 11 then make_indicator11(p)
	else                   make_indicator03(p)
	end

	-- cairo_save(cr)
end

----------------------------------------------------------------------
local function do_windvane(vala)		------------ {{{
	local wx       = vala.lwx
	local wy	   = vala.lwy
	local rout     = (vala.s*0.52)
	local wdeg     = vala.d or "NA"
	-- local wdeg     = vala.d
	local wspeed   = vala.e or "NA"
	local file1    = vala.i or "NA"
	local wv_arrow = vala.a or 3
	local bimage   = vala.j or nil
	local acolour1 = vala.l or tconcat({Red,':1'})
	local bcolour1 = vala.b or tconcat({MidnightBlue,':0.7'})
	local rcolour1 = vala.r or tconcat({Gold,':1'})
	local scolour1 = vala.o or tconcat({RoyalBlue,':1'})
	local tcolour1 = vala.c or tconcat({Lime,':1'})
	local nring    = vala.nring or nil
	local star_style  = vala.y or 5
	local star_sizet  = vala.z or "l"
	local stroke_fill = vala.x or "s"
	local wvpath   = vala.imgpath
	local updates1   = vala.info

	local x_image_corr       = 0
	local y_image_corr       = 0

	local updates = tonum(conky_parse("${updates}"))

	local random_seed = 0

	local acolour = wxsplit(acolour1,":")
	local bcolour = wxsplit(bcolour1,":")
	local rcolour = wxsplit(rcolour1,":")
	local scolour = wxsplit(scolour1,":")
	local tcolour = wxsplit(tcolour1,":")

	if tonum(bimage) == 0 then bimage = nil end

	if not bimage and file1 ~= "NA" then
		routI = vala.s / 100
		rout = vala.s * 0.52
	elseif tonum(bimage) == 1 then
		routI = vala.s /110
		rout = vala.s * 0.45
	elseif tonum(bimage) == 2 then
		routI = vala.s /109
		rout = vala.s * 0.45
	end

	local rin=rout-((rout/100)*10)

	if not nring then
		wx = vala.lwx+(vala.s/2)+5
		wy = vala.lwy+(vala.s/2)
	else
		wx = vala.lwx
		wy = vala.lwy
	end

	-- wdeg=180
	-- print(wdeg)

	if  wdeg       and
		wdeg~="NA" and
		wdeg~="Var" then
		wdeg = tonum(wdeg)
	end
	if  wdeg and type(wdeg) == "number" then
		local wdir_variance = 7
		wdeg = wdeg + random(-wdir_variance,wdir_variance)
		-- wdeg = wdeg
	elseif wdeg == "Var" then
		local wvar1 = (( updates % 5) + 1)
		if wvar1 == 1 then
			wdeg = random(0,360)
			last_val = wdeg
		else
			wdeg = last_val
		end
	end
	-- print(file1)
	-- wdeg=90

	if file1 == "NA" or file1 == "0" then

		if tonum(bimage) == 2 then
			cairo_save(cr)
			make_bezel({ bezel_size = vala.s*1.035, px = wx, py = wy })
			cairo_restore(cr)
			-- nring = nil
		end
		-- ring for cardinal points
		-- cairo_set_source_rgba (cr, to_rgba(ring_bground))
		cairo_set_source_rgba (cr, to_rgba(bcolour))
		cairo_arc (cr,wx,wy,rout,TORADIANS,0)
		cairo_fill (cr)
		------------------------------------
		-- local slim=100
		-- local star_step=22.5
		-- local slim_step=90
		-- local star_size=rout
		if string.upper(star_sizet) == "L" then
			star_size=96
		else
			star_size=50
		end

		-- TODO: use string match to fine : in string and break into three componenets for star
		-- star_style = "50:45:45"
		-- star_style = tostring(9)
		-- if star_style:match(":") then print("yohhoo") else print("aha") end

		-- local star_colour={0x00fff9,1}
		local line_thickness=1
		-- local stroke_fill="f"
		if star_style then
			if string.upper(star_style) == "D" then
				wvtimer=((updates%10)+1)
				-- print(wvtimer*5) {{{
				for j=0,100 do
					if wvtimer == j then
						if not slim then slim=j*10
						elseif slim==100 and slim_step==90 and star_step==90 then
							slim=j*-10
						elseif slim==-100 and slim_step==90 and star_step==90 then
							slim=j*10
						elseif slim > 0 and slim_step <=90 and star_step<=90 then
							slim=j*10
						elseif slim < 0 and slim_step <=90 and star_step<=90 then
							slim=j*-10
						end
						if not slim_step then slim_step=0
						elseif abs(slim) == 10 then slim_step=slim_step+22.5
						end
						if star_step==nil then star_step=22.5 end
						if abs(slim_step)==67.5 then slim_step = 90 end
						if abs(slim_step)> 100 then slim_step = 0  end
						if abs(slim)==10 and slim_step==0 then star_step=star_step+22.5 end
						if abs(star_step)==67.5 then star_step = 90 end
						if abs(star_step) > 100 then star_step = 22.5  end
						lastval=slim
						print(tconcat({slim,":",slim_step,":",star_step}))
					else
						slim=lastval
					end
				end
			elseif type(star_style) ~= "number" and star_style:match(":") then
				sst = wxsplit(star_style,":")
				-- print(sst[1],sst[2],sst[3])
				slim     =sst[1] or print("Star style requires 3 arguments")
				slim_step=sst[2] or print("Star style requires 3 arguments")
				star_step=sst[3] or print("Star style requires 3 arguments")
			else
				local sst1 = tonum(star_style)
				if sst1 == 1 then
					slim=15; slim_step=22.5; star_step=45
				elseif sst1 == 2 then
					slim=20; slim_step=11.25; star_step=22.5
				elseif sst1 == 3 then
					slim=100; slim_step=22.5; star_step=22.5
				elseif sst1 == 4 then
					slim=100; slim_step=90; star_step=45
				elseif sst1 == 5 then
					slim=100; slim_step=45; star_step=45
				else
					slim=100; slim_step=45; star_step=45
				end
			end

			for i=0,360,star_step do
				local rout2=(rout*(star_size*0.01))
				local pxa1,pya1=get_points(0,i,slim_step,rout2*(slim*0.01))
				local pxa2,pya2=get_points(0,i,star_step,-rout2*1)
				cairo_line_to(cr, wx+pxa1, wy+pya1)
				cairo_line_to(cr, wx+pxa2, wy+pya2)
			end
			cairo_close_path(cr)
			cairo_set_source_rgba (cr, to_rgba(scolour))
			cairo_set_line_width (cr,line_thickness)
			if not stroke_fill then cairo_stroke(cr)
			elseif string.upper(stroke_fill) == "S" then cairo_stroke(cr)
			elseif string.upper(stroke_fill) == "F" then cairo_fill(cr)
			else cairo_stroke(cr)
			end
		end

		---------------------------------}}}
		-- cairo_set_source_rgba (cr, to_rgba(rcolour))
		if tonum(bimage) ~= 2 then
			if nring then
				cairo_set_source_rgba (cr, to_rgba(bcolour))
				cairo_set_line_width (cr,1)
				cairo_arc (cr,wx,wy,rout,TORADIANS,0)
			else
				cairo_set_source_rgba (cr, to_rgba(rcolour))
				cairo_arc (cr,wx,wy,rout,TORADIANS,0)
			end
			cairo_stroke (cr)
		end

		cairo_set_source_rgba (cr, to_rgba(rcolour))
		cairo_set_line_width (cr,1)
		for i=1,36 do
			cairo_save(cr)
			make_scale_txt2({
				startscale	= 0,
				endscale	= 10,
				maxscale	= 1,
				rout		= rout,
				rin			= rin,
				xval		= wx,
				yval		= wy,
				i			= i		})
		end
		--print cardinal directions
		-- local font="Mono"
		local fsize=(rout/5)
		if fsize < 8 then fsize = 8 end
		cairo_save(cr)
		-- set_font("Mono:fsize")
		set_font("Mono:fsize:bold")
		if rout < 35 then dirs={"N","E","S","W"}
		else dirs={"N","NE","E","SE","S","SW","W","NW"} end
		local rdir=rout-((rout/100)*32)
		for i=1,#dirs do
			make_scale_txt2({
				startscale	= 0,
				endscale	= 360,
				maxscale	= #dirs,
				trout		= rdir,
				dotext      = 1,
				text		= dirs[i],
				xval		= wx,
				yval		= wy,
				i			= i-1	})
		end
	else
		local fileN
		if tonum(file1) then
			fileN = tconcat({wvpath,"/lua_windvane/windvane-",file1,".png"})
		else
			fileN = file1
		end
		if FileExists(fileN) then
			if tonum(bimage) == 2 then
				cairo_save(cr)
				make_bezel({ bezel_size = vala.s*1.035, px = wx, py = wy })
				cairo_restore(cr)
				put_image({x=wx+(x_image_corr or 0), y=wy+(y_image_corr or 0), file=fileN, scale=routI})
			else
				put_image({x=wx+(x_image_corr or 0), y=wy+(y_image_corr or 0), file=fileN, scale=routI})
			end
		end
	end

	-- indicator arrow
	local npr=rout-((rout/100)*15)

	if wdeg=="NA" then
		-- local font1="Mono"
		if not nring then
			fsize1=(rout/2.657778)
		else
			fsize1=(rout/3.43)
			-- print(rout)
		end

		if wspeed == "Calm" then
		-- if type(wspeed) == 'string' then
			wdeg = wspeed
			cairo_set_source_rgba (cr, to_rgba(tcolour))
		else
			cairo_set_source_rgba (cr, to_rgba(acolour))
		end
		cairo_save(cr)
		set_font(tconcat({"Mono:",fsize1,":bold"}))
		text1=wdeg
		extents=cairo_text_extents_t:create()
		cairo_text_extents(cr,text1,extents)
		width=extents.width
		height=extents.height
		-- if not nring then
			-- cairo_move_to (cr,wx-width/2,wy+12-height/2)
		-- else
			cairo_move_to (cr,wx-width/2,wy+height/2)
		-- end
		cairo_show_text (cr,text1)
		cairo_stroke (cr)
	else
		-- if wv_arrow or wv_arrow ~= "NA" then
		-- if tonum(wv_arrow) then
			wv_arrow = tonum(wv_arrow)
			-- wv_arrow = 5
			if wv_arrow ~= 1 and wdeg then wdeg = wdeg + 180 end
			if wv_arrow > 10 then
				arrow = wv_arrow
				wv_arrow = 11
			else
				arrow = wv_arrow
			end

		-- Let Lua draw the compass arrow -- }}}
		cairo_save(cr)
		local ind_length=rout-((rout/100)*15)
		local thickness=rout-((rout/100)*88)
		if wdeg==nil then wdeg=0 end
		choose_indicator({
			startval= 0,
			range	= 360,
			scale	= wdeg,
			rout1	= ind_length,
			rin3	= thickness,
			px		= wx,
			py		= wy,
			arrow   = arrow,
			ch_indi = wv_arrow,
			icolour = acolour,
			ip      = wvpath,
		})
	end -- indicator arrow end
	if tonum(bimage) == 1 then
		cairo_save(cr)
		instrument_sqr({routI=vala.s, wx=wx, wy=wy})
	end

	-- cairo_destroy(cr)

end--compass end		------------ }}}


----------------------------------------------------------------------
local function do_showcond(vala)		------------ {{{

	local wx 	 	= vala.lwx+(vala.s/2)
	local wy 	 	= vala.lwy+(vala.s/2)
	local rout   	= vala.s or 100
	local wdeg   	= tonum(vala.d)
	local fileA  	= vala.i 			or "NA"
	local bimage 	= vala.j            or nil
	local Ctype  	= vala.f 			or "-"
	local show_what = string.upper(vala.w) -- Cond / Wind / Moon
	local showthick = vala.t
	local sccolour 	= vala.c			or tconcat({Lime,":1"})

	if tonum(bimage) == 0 then bimage = nil end

	local mcolour = wxsplit(sccolour,":")

	if show_what == "CF" then font1="ConkyWeather"
	elseif show_what == "WF" then font1="ConkyWindNESW"
	elseif show_what == "MF" then font1="Moon Phases"
	end

	if Ctype == '\\#' then Ctype = "#" end --character type

	local compare = { CF = true, WF = true, MF = true }

	-- if show_what == "CF" or show_what == "WF" or show_what == "MF" then
	if compare[show_what] then
		if tonum(bimage) == 2 then
			cairo_save(cr)
			make_bezel({ bezel_size = rout*1.035, px = wx+5, py = wy })
			cairo_restore(cr)
		end
		local fsize1=vala.s
		cairo_save(cr)
		-- local ftype
		if showthick == "1" then
			if show_what == "CF" then
				set_font(tconcat({font1,":",fsize1,":bold"}))
			else
				set_font(tconcat({font1,":",fsize1,":normal"}))
			end
		else
			set_font(tconcat({font1,":",fsize1,":normal"}))
		end
		-- cairo_set_font_size (cr, fsize1)
		text1=Ctype
		extents=cairo_text_extents_t:create()
		cairo_text_extents(cr,text1,extents)
		width=extents.width
		height=extents.height
		local fx=vala.lwx+5
		local fy=vala.lwy+(rout*0.095)+height
		-- print(width,height)
		if showthick == "1" then
			cairo_set_source_rgba (cr, to_rgba({Black,0.35}))
			cairo_move_to (cr,fx+(rout*.020),fy+(rout*.020))
			cairo_show_text (cr,text1)
			cairo_set_source_rgba (cr, to_rgba(mcolour))
			cairo_move_to (cr,fx,fy)
			cairo_show_text (cr,text1)
			cairo_move_to (cr,fx+1,fy+1)
			cairo_show_text (cr,text1)
			cairo_save(cr)
			set_font(tconcat({font1,":",fsize1,":normal"}))
			if show_what ~= "MF" then
				cairo_set_source_rgba (cr, to_rgba({Black,0.4}))
				cairo_move_to (cr,fx+(rout*.015),fy+(rout*.015))
				cairo_show_text (cr,text1)
			end
		else
			cairo_set_source_rgba (cr, to_rgba(mcolour))
			cairo_move_to (cr,fx,fy)
			cairo_show_text (cr,text1)
		end
		cairo_stroke (cr)
		if tonum(bimage) == 1 then
			cairo_save(cr)
			instrument_sqr({routI=rout, wx=wx+5, wy=wy})
		end
	else
		wx = wx; wy = wy+1
		if show_what == "CI" then
			if FileExists(fileA) then
				cairo_move_to (cr,wx,wy)
				if not bimage or bimage == 'NA' then
					put_image({x=wx, y=wy, file=fileA, scale=(rout/100) })
				elseif tonum(bimage) == 1 then
					-- cairo_move_to (cr,wx,wy)
					put_image({x=wx, y=wy, file=fileA, scale=(rout/109), night=1})
					cairo_save(cr)
					instrument_sqr({routI=rout, wx=wx, wy=wy})
				elseif tonum(bimage) == 2 then
					cairo_save(cr)
					make_bezel({ bezel_size = rout*1.035, px = wx, py = wy })
					cairo_restore(cr)
					put_image({x=wx+0.5, y=wy+0.5, file=fileA, scale=(rout/109) })
				end
			end
		elseif show_what == "MI" then

			-- 0 45 90 135 180 225 270 315 360
			-- wdeg = 360
			-- fileA='/home/param/bin/projects/conkywx/conkywx_source/1.0.1/conkywx_1.0.1_source/images/moonicons/15.png'

			local arc = TORADIANS * wdeg
			if FileExists(fileA) then
				cairo_move_to (cr,wx,wy)
				if not bimage or bimage == 'NA' then
					put_image({x=wx+0.5, y=wy+0.5, file=fileA, scale=(rout/108), theta=arc, rotate=true})
				elseif tonum(bimage) == 1 then
					put_image({x=wx+0.5, y=wy+0.5, file=fileA, scale=(rout/108), theta=arc, rotate=true})
					cairo_save(cr)
					instrument_sqr({routI=rout, wx=wx, wy=wy})
				elseif tonum(bimage) == 2 then
					cairo_save(cr)
					make_bezel({ bezel_size = rout*1.035, px = wx, py = wy })
					cairo_restore(cr)
					put_image({x=wx+0.5, y=wy+0.5, file=fileA, scale=(rout/108), theta=arc, rotate=true})
				end
			end
		elseif show_what == "WI" then
			local w_vane = {
				lwx   = vala.lwx,
				lwy	  = vala.lwy,
				s  	  = vala.s,
				d     = vala.d,
				e     = vala.e,
				i     = vala.i,
				a     = vala.a,
				j     = vala.j,
				l 	  = vala.l,
				b 	  = vala.b,
				r 	  = vala.r,
				o 	  = vala.o,
				c 	  = vala.c,
				y 	  = vala.y,
				z 	  = vala.z,
				x 	  = vala.x,
				imgpath = vala.imgpath,
				nring = nil
			}
			do_windvane(w_vane)
			-- print(vala.d)
		end
	end

end--showcond end		------------ }}}


----------------------------------------------------------------------
local function do_thermometer(vala)		------------ {{{
	local units = vala.u or print("Thermometer Units missing")
	local scale = vala.s
	local temp  = vala.t
	local label = vala.l
	local mx    = vala.lwx*(1/scale)+30
	local my    = vala.lwy*(1/scale)-25

	local scale_color        = vala.c or tconcat({DarkGold,":1"})
	local scale_lines        = vala.d or tconcat({Gold,":0.5"})
	local scale_text_colour  = vala.e or tconcat({RoyalBlue,":1"})
	local temp_readout       = vala.f or tconcat({RoyalBlue,":1"})

	scale_color 		 = wxsplit(scale_color,":")
	scale_lines 		 = wxsplit(scale_lines,":")
	scale_text_colour  	 = wxsplit(scale_text_colour,":")
	temp_readout 		 = wxsplit(temp_readout,":")

	local temp1={}
	if not temp then
		temp = 0
	else
		-- local wxx1, wxx2, wxx3 = temp:find("(%-?%d+%.?%d?)")
		local wxx1, wxx2, wxx3 = temp:find('(%-?[%d%.]+)')
		temp  = tonum(wxx3)
	end
	-- print(">"..vala.t)
	if label == "NA" or label == "NA" then label = " " end
	if scale==nil then scale=1 end
	if units == "F" then
		height = 150
		mid    = 74
	elseif units == "C" then
		height = 160
		mid    = 21
	end
	-- height = 160
	-- local font="Mono"
	local fsize=10
	cairo_scale (cr,scale,scale)
	cairo_set_line_width (cr,1.5)
	cairo_set_source_rgba (cr, to_rgba(scale_color))
	--graphics outer
	--bottom circle
	r_outer=25
	local lang_outer=335
	local rang_outer=0+(360-lang_outer)
	local h_outer=height-4--maybe make this a percentage?###########
	cairo_arc (cr,mx,my,r_outer,TORADIANS*(rang_outer-90),TORADIANS*(lang_outer-90))
	--coordinates,left line
	local arc=TORADIANS*lang_outer
	local lxo=0+r_outer*(sin(arc))
	local lyo=0-r_outer*(cos(arc))
	cairo_line_to (cr,mx+lxo,my+lyo-h_outer)
	--coordinates,left line
	local arc=TORADIANS*rang_outer
	local rxo=0+r_outer*(sin(arc))
	local ryo=0-r_outer*(cos(arc))
	--top circle
	cairo_arc (cr,mx+lxo+((rxo-lxo)/2),my+lyo-h_outer,(rxo-lxo)/2,TORADIANS*(270-90),TORADIANS*(90-90))
	--right line
	cairo_line_to (cr,mx+lxo+((rxo-lxo)),my+lyo)
	cairo_stroke (cr)
	----------------------------------------------
	--graphics inner
	if units=="F" then
		local str,stg,stb,sta=0,1,1,1
		local mr,mg,mb,ma=1,1,0,1
		local fr,fg,fb,fa=1,0,0,1
		local nd=150
		if temp==nil then temp=0 end
		local tadj=temp+30
		local middle=mid+30
		if tadj<(middle) then
			colr=((mr-str)*(tadj/(middle)))+str
			colg=((mg-stg)*(tadj/(middle)))+stg
			colb=((mb-stb)*(tadj/(middle)))+stb
			cola=((ma-sta)*(tadj/(middle)))+sta
		elseif tadj>=(middle) then
			colr=((fr-mr)*((tadj-(middle))/(nd-middle)))+mr
			colg=((fg-mg)*((tadj-(middle))/(nd-middle)))+mg
			colb=((fb-mb)*((tadj-(middle))/(nd-middle)))+mb
			cola=((fa-ma)*((tadj-(middle))/(nd-middle)))+ma
		end
		cairo_set_source_rgba (cr,colr,colg,colb,cola)
		--bottom circle
		r_inner=r_outer-6
		local lang_inner=lang_outer+9
		local rang_inner=0+(360-lang_inner)
		local h_inner=temp+30
		cairo_arc (cr,mx,my,r_inner,TORADIANS*(rang_inner-90),TORADIANS*(lang_inner-90))
		--coordinates,left line
		local arc=TORADIANS*lang_inner
		lxi=0+r_inner*(sin(arc))
		local lyi=0-r_inner*(cos(arc))
		cairo_line_to (cr,mx+lxi,my+lyi-h_inner)
		--coordinates,left line
		local arc=TORADIANS*rang_inner
		rxi=0+r_inner*(sin(arc))
		local ryi=0-r_inner*(cos(arc))
		--top circle
		cairo_arc (cr,mx+lxi+((rxi-lxi)/2),my+lyi-h_inner,(rxi-lxi)/2,TORADIANS*(270-90),TORADIANS*(90-90))
		--right line
		cairo_line_to (cr,mx+lxi+((rxi-lxi)),my+lyi)
		cairo_fill (cr)
		----------------------------
		if label~="none" then
		--scale lines
			cairo_set_line_width (cr,1)
			cairo_set_source_rgba (cr, to_rgba(scale_lines))
			-- cairo_set_source_rgba (cr,1,1,1,0.5)
			local grad=10
			local lnn=15
			local lnx=mx+lxo
			local lnw=(rxo-lxo)
			for i=1,lnn do
				lny=my-r_inner-(10+((i-1)*grad))-((rxi-lxi)/2)
				if i==lnn then
					lnx=lnx+2
					lnw=lnw-4
				end
				cairo_move_to (cr,lnx,lny)
				cairo_rel_line_to (cr,lnw,0)
				cairo_stroke (cr)
			end
			--numbers
			cairo_set_source_rgba (cr, to_rgba(scale_text_colour))
			-- cairo_set_source_rgba (cr,1,1,1,1)
			cairo_select_font_face (cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
			cairo_set_font_size (cr, fsize)
			local grad=20
			local lnn=8
			local lnx=mx+lxo+(rxo-lxo)+4
			num={-20,tconcat({"0°",units}),20,40,60,80,100,120}
			for i=1,lnn do
				lny=my-r_inner-(10+((i-1)*grad))-((rxi-lxi)/2)+(fsize/3)
				cairo_move_to (cr,lnx,lny)
				cairo_show_text (cr,num[i])
				cairo_stroke (cr)
			end
		end--if label=none
	end--if units=F
	--#################################################
	if units=="C" then
	--from -30 to 50 C
		local str,stg,stb,sta=0,1,1,1
		local mr,mg,mb,ma=1,1,0,1
		local fr,fg,fb,fa=1,0,0,1
		local nd=160
		if temp==nil then temp=0 end
		local tadj=(temp*2)+60
		local middle=(mid*2)+60
		if tadj<(middle) then
			colr=((mr-str)*(tadj/(middle)))+str
			colg=((mg-stg)*(tadj/(middle)))+stg
			colb=((mb-stb)*(tadj/(middle)))+stb
			cola=((ma-sta)*(tadj/(middle)))+sta
		elseif tadj>=(middle) then
		-- elseif tadj>=(120) then
		-- Paramvir - 120 value is this a bug ??? if mid = temp this fails
			colr=((fr-mr)*((tadj-(middle))/(nd-middle)))+mr
			colg=((fg-mg)*((tadj-(middle))/(nd-middle)))+mg
			colb=((fb-mb)*((tadj-(middle))/(nd-middle)))+mb
			cola=((fa-ma)*((tadj-(middle))/(nd-middle)))+ma
		end
		-- print(tadj,middle,temp,colr,colg,colb,cola)
		cairo_set_source_rgba (cr,colr,colg,colb,cola)
		-- cairo_set_source_rgba (cr,0,1,1,1)
		--bottom circle
		r_inner=r_outer-6
		local lang_inner=lang_outer+9
		local rang_inner=0+(360-lang_inner)
		local h_inner=(temp*2)+60
		cairo_arc (cr,mx,my,r_inner,TORADIANS*(rang_inner-90),TORADIANS*(lang_inner-90))
		--coordinates,left line
		local arc=TORADIANS*lang_inner
		lxi=0+r_inner*(sin(arc))
		local lyi=0-r_inner*(cos(arc))
		cairo_line_to (cr,mx+lxi,my+lyi-h_inner)
		--coordinates,left line
		local arc=TORADIANS*rang_inner
		rxi=0+r_inner*(sin(arc))
		local ryi=0-r_inner*(cos(arc))
		--top circle
		cairo_arc (cr,mx+lxi+((rxi-lxi)/2),my+lyi-h_inner,(rxi-lxi)/2,TORADIANS*(270-90),TORADIANS*(90-90))
		--right line
		cairo_line_to (cr,mx+lxi+((rxi-lxi)),my+lyi)
		cairo_fill (cr)
		----------------------------
		if label~="none" then
			--scale lines
			cairo_set_line_width (cr,1)
			cairo_set_source_rgba (cr, to_rgba(scale_lines))
			-- cairo_set_source_rgba (cr,255/255,165/255,79/255,0.5)
			local grad=10
			local lnn=17
			local lnx=mx+lxo
			local lnw=(rxo-lxo)
			for i=1,lnn do
				lny=my-r_inner-(((i-1)*grad))-((rxi-lxi)/2)
				if i==lnn then
					lnx=lnx+2
					lnw=lnw-4
				end
				cairo_move_to (cr,lnx,lny)
				cairo_rel_line_to (cr,lnw,0)
				cairo_stroke (cr)
			end
			--numbers
			cairo_set_source_rgba (cr, to_rgba(scale_text_colour))
			-- cairo_set_source_rgba (cr,255/255,99/255,71/255,255/255)
			cairo_select_font_face (cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
			cairo_set_font_size (cr, fsize)
			local grad=20
			local lnn=9
			local lnx=mx+lxo+(rxo-lxo)+4
			num={-30,-20,-10,tconcat({"0°",units}),10,20,30,40,50}
			for i=1,lnn do
				lny=my-r_inner-(((i-1)*grad))-((rxi-lxi)/2)+(fsize/3)
				cairo_move_to (cr,lnx,lny)
				cairo_show_text (cr,num[i])
				cairo_stroke (cr)
			end
		end--if label=none
	end--if units=C
	--#################################################
	--label
	if label~="none" then
		-- local font="Mono"
		local fsize=12
		cairo_select_font_face (cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
		cairo_set_font_size (cr, fsize)
		local lbx=mx+lxo-5
		local lby=my-r_inner-10-((rxi-lxi)/2)
		cairo_move_to (cr,lbx,lby)
		cairo_rotate (cr,TORADIANS*(-90))
		cairo_show_text (cr,label)
		cairo_stroke (cr)
		cairo_rotate (cr,TORADIANS*(90))
		--temperature readout
		cairo_set_source_rgba (cr, to_rgba(temp_readout))
		-- cairo_set_source_rgba (cr,0,0,0,1)
		cairo_select_font_face (cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
		local text=tconcat({temp,"°",units})
		local extents=cairo_text_extents_t:create()
		cairo_text_extents(cr,text,extents)
		local width=extents.width
		local height=extents.height
		cairo_move_to (cr,mx-(width/2),my+(height/2))
		cairo_show_text (cr,text)
		cairo_stroke (cr)
	end--if label
	------------------------------------
	cairo_scale (cr,1/scale,1/scale)
end		------------ }}}

----------------------------------------------------------------------
local function do_wxgraph(vala)		------------ {{{
	-- local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
	-- cr = cairo_create(cs)
	local hori = tonum(vala.lwx)
	local vert = tonum(vala.lwy)
	local sccolour 	= vala.c			or "0x00ff00:1"

	local mcolour = wxsplit(sccolour,":")

	local t1 = wxsplit(vala.d,",")

	local th_fact = nil
	local wxgfactor = vala.s or 1
	if wxgfactor == 1 then th_fact = 1 else th_fact = wxgfactor*0.7 end
	local width = 3.7 * wxgfactor
	-- local width=3.7
	local thick = 2 * th_fact
	if width < 0 then
		hori1=hori-(length*width)-width
	elseif width > 0 then
		hori1=hori
	end

	cairo_set_line_width (cr, thick)
	cairo_set_source_rgba (cr, to_rgba(mcolour))
	for i = 1,#t1-1 do
		t1[i]=t1[i]*(wxgfactor)
		cairo_translate (cr, hori1, vert)
		cairo_move_to (cr, width*i,  -t1[i])
		cairo_line_to (cr, width*(i+0.65), -t1[i])
		cairo_stroke (cr)
		cairo_translate (cr, -hori1, -vert)
	end
end		------------ }}}


----------------------------------------------------------------------
local function do_background (vala)		------------ {{{

--[[
Background Idea by londonali1010 (2009)
reinvented by Paramvir Likhari 2014

This script draws a background on the Conky window or can be
used to place shaded squares anywhere within the conky window.

Use -s w,h to state size - will fill window if NA,NA given
Use -p x,y for position - will use 0,0 if no position given
This allows you to have multiple backgrounds per conky window
code based on instrument_sqr - perhaps will unify one day ;-)


Changelog:
+ v1.0 -- Original release (07.10.2009)
]]

-- Change these settings to affect your background.

	local wsize = nil
	local xsize = nil
	local ysize = nil
	local px = nil
	local py = nil
	if vala.s then
		wsize = wxsplit(vala.s,",")
		xsize = wsize[1]:match( "^%s*(.-)%s*$" )
		ysize = wsize[2]:match( "^%s*(.-)%s*$" )
	else
		xsize,ysize=0,0
	end
	if vala.p then
		wsize = wxsplit(vala.p,",")
		px = wsize[1]:match( "^%s*(.-)%s*$" )
		py = wsize[2]:match( "^%s*(.-)%s*$" )
	else
		px,py=0,0
	end
	-- print(xsize,ysize,vala.s,vala.p)
	-- print(px,py)

	local cnr  = vala.r or 25

-- Set the colour and transparency (alpha) of your background.

	local bgcolour 	= vala.c or "0x000000:0.2"
	local bgcolour = wxsplit(bgcolour,":")
	-----------------------------------------
	local width     = xsize or conky_window.width
	local height    = ysize or conky_window.height

	if width == "NA" or width == "NA" then
		width = conky_window.width
	end
	if height == "NA" or height == "NA" then
		height = conky_window.height
	end

	local w=width+px
	local h=height+py
	-- local cs=cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	-- local cr=cairo_create(cs)

	local crtlx=px
	local crtly=py
	-----------------------------------------
	-- local cnr=25
	-----------------------------------------
	cairo_move_to(cr, crtlx, crtly+cnr)
	cairo_line_to(cr, crtlx, h-cnr)
	cairo_curve_to(cr,crtlx,h,crtlx,h,crtlx+cnr,h)
	cairo_line_to(cr, w-cnr, h)
	cairo_curve_to(cr,w,h,w,h,w,h-cnr)
	cairo_line_to(cr, w, crtly+cnr)
	cairo_curve_to(cr,w,crtly,w,crtly,w-cnr,crtly)
	cairo_line_to(cr, crtlx+cnr, crtly)
	cairo_curve_to(cr,crtlx,crtly,crtlx,crtly,crtlx,crtly+cnr)
	cairo_close_path(cr)

	cairo_set_source_rgba(cr, to_rgba(bgcolour))
	cairo_fill(cr)
	return ""
end		------------ }}}

----------------------------------------------------------------------
local function do_bargraph(t)		------------ {{{
--[[
BARGRAPH WIDGET
v2.1 by wlourf (07 Jan. 2011)
this widget draws a bargraph with different effects
http://u-scripts.blogspot.com/2010/07/bargraph-widget.html

To call the script in a conky, use, before TEXT
	lua_load /path/to/the/script/bargraph.lua
	lua_draw_hook_pre main_rings
and add one line (blank or not) after TEXT

Parameters are :
3 parameters are mandatory
name - the name of the conky variable to display, for example for {$cpu cpu0}, just write name="cpu"
arg  - the argument of the above variable, for example for {$cpu cpu0}, just write arg="cpu0"
	   arg can be a numerical value if name=""
max  - the maximum value the above variable can reach, for example, for {$cpu cpu0}, just write max=100

Optional parameters:
x,y	  - coordinates of the starting point of the bar, default = middle of the conky window
cap	  - end of cap line, ossibles values are r,b,s (for round, butt, square), default="b"
		http://www.cairographics.org/samples/set_line_cap/
angle	  - angle of rotation of the bar in degress, default = 0 (i.e. a vertical bar)
		set to 90 for an horizontal bar
skew_x	  - skew bar around x axis, default = 0
skew_y	  - skew bar around y axis, default = 0
blocks    - number of blocks to display for a bar (values >0) , default= 10
height	  - height of a block, default=10 pixels
width	  - width of a block, default=20 pixels
space	  - space between 2 blocks, default=2 pixels
angle_bar - this angle is used to draw a bar on a circular way (ok, this is no more a bar !) default=0
radius	  - for cicular bars, internal radius, default=0
		with radius, parameter width has no more effect.

Colours below are defined into braces {colour in hexadecimal, alpha}
fg_colour    - colour of a block ON, default= {0x00FF00,1}
bg_colour    - colour of a block OFF, default = {0x00FF00,0.5}
alarm	     - threshold, values after this threshold will use alarm_colour colour , default=max
alarm_colour - colour of a block greater than alarm, default=fg_colour
smooth	     - (true or false), create a gradient from fg_colour to bg_colour, default=false
mid_colour   - colours to add to gradient, with this syntax {position into the gradient (0 to1), colour hexa, alpha}
		   for example, this table {{0.25,0xff0000,1},{0.5,0x00ff00,1},{0.75,0x0000ff,1}} will add
		   3 colours to gradient created by fg_colour and alarm_colour, default=no mid_colour
led_effect   - add LED effects to each block, default=no led_effect
		   if smooth=true, led_effect is not used
		   possibles values : "r","a","e" for radial, parallel, perdendicular to the bar (just try!)
		   led_effect has to be used with theses colours :
fg_led	     - middle colour of a block ON, default = fg_colour
bg_led	     - middle colour of a block OFF, default = bg_colour
alarm_led    - middle colour of a block > ALARM,  default = alarm_colour

reflection parameters, not available for circular bars
reflection_alpha  - add a reflection effect (values from 0 to 1) default = 0 = no reflection
			other values = starting opacity
reflection_scale  - scale of the reflection (default = 1 = height of text)
reflection_length - length of reflection, define where the opacity will be set to zero
			values from 0 to 1, default =1
reflection	  - position of reflection, relative to a vertical bar, default="b"
			possibles values are : "b","t","l","r" for bottom, top, left, right
draw_me     	  - if set to false, text is not drawn (default = true or 1)
			it can be used with a conky string, if the string returns 1, the text is drawn :
			example : "${if_empty ${wireless_essid wlan0}}${else}1$endif",

v1.0 (10 Feb. 2010) original release
v1.1 (13 Feb. 2010) numeric values can be passed instead conky stats with parameters name="", arg = numeric_value
v1.2 (28 Feb. 2010) just renamed the widget to bargraph
v1.3 (03 Mar. 2010) added parameters radius & angle_bar to draw the bar in a circular way
v2.0 (12 Jul. 2010) rewrite script + add reflection effects and parameters are now set into tables
v2.1 (07 Jan. 2011) Add draw_me parameter and correct memory leaks, thanks to "Creamy Goodness"
30 Jan. 2014 - paramvir [conkywx] fixed the alarm colour except 20 to 89 degrees

August 2015  - paramvir parts recoded

--      This program is free software; you can redistribute it and/or modify
--      it under the terms of the GNU General Public License as published by
--      the Free Software Foundation version 3 (GPLv3)
--
--      This program is distributed in the hope that it will be useful,
--      but WITHOUT ANY WARRANTY; without even the implied warranty of
--      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--      GNU General Public License for more details.
--
--      You should have received a copy of the GNU General Public License
--      along with this program; if not, write to the Free Software
--      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
--      MA 02110-1301, USA.

]]

	cairo_save(cr)
	--check values
	if t.name==nil and t.arg==nil then
		print ("No input values ... use parameters 'name' with 'arg' or only parameter 'arg' ")
		return
	end
	if t.max==nil then
		print ("No maximum value defined, use 'max'")
		return
	end

	t.name = t.name  or ''
	t.arg  = t.arg   or ''

	--set default values
	t.x = t.x        or conky_window.width/2
	t.y = t.y        or conky_window.height/2
	t.blocks = t.blocks or 10
	t.height = t.height or 10
	t.angle  = t.angle  or 0
	t.angle  = t.angle*PI/180
	--line cap style
	t.cap = t.cap or 'b'

	local cap="b"
	for i,v in ipairs({"s","r","b"}) do
		if v==t.cap then cap=v end
	end
	delta=0
	if t.cap=="r" or t.cap=="s" then delta = t.height end
	if cap=="s" then
		cap = CAIRO_LINE_CAP_SQUARE
	elseif cap=="r" then
		cap = CAIRO_LINE_CAP_ROUND
	elseif cap=="b" then
		cap = CAIRO_LINE_CAP_BUTT
	end
	--end line cap style

	t.width     = t.width      or 20
	t.space     = t.space      or 2
	t.radius    = t.radius     or 0
	t.angle_bar = t.angle_bar  or 0
	t.angle_bar = t.angle_bar*PI/360 --halt angle

	--colours
	t.bg_colour = t.bg_colour or {0x00FF00,0.5}
	if #t.bg_colour~=2 then t.bg_colour = {0x00FF00,0.5} end

	t.fg_colour = t.fg_colour or {0x00FF00,1}
	if #t.fg_colour~=2 then t.fg_colour = {0x00FF00,1} end

	t.alarm_colour = t.alarm_colour or t.fg_colour
	if #t.alarm_colour~=2 then t.alarm_colour = t.fg_colour end

	if t.mid_colour then
		for i=1, #t.mid_colour do
			if #t.mid_colour[i]~=3 then
				print ("error in mid_color table")
				t.mid_colour[i]={1,0xFFFFFF,1}
			end
		end
	end

	if t.bg_led and #t.bg_led~=2      then t.bg_led = t.bg_colour end
	if t.fg_led and #t.fg_led~=2      then t.fg_led = t.fg_colour end
	if t.alarm_led~= nil and #t.alarm_led~=2 then t.alarm_led = t.fg_led end

	if t.led_effect then
		if not t.bg_led     then t.bg_led = t.bg_colour end
		if not t.fg_led     then t.fg_led = t.fg_colour end
		if not t.alarm_led  then t.alarm_led = t.fg_led end
	end


	if not t.alarm  then t.alarm = t.max end --0.8*t.max end
	if not t.smooth then t.smooth = false end

	if not t.skew_x then
		t.skew_x=0
	else
		t.skew_x = PI*t.skew_x/180
	end
	if not t.skew_y then
		t.skew_y=0
	else
		t.skew_y = PI*t.skew_y/180
	end

	t.reflection_alpha  = t.reflection_alpha  or 0
	t.reflection_length = t.reflection_length or 1
	t.reflection_scale  = t.reflection_scale  or 1

	--end of default values

	--functions used to create patterns

	local function create_smooth_linear_gradient(x0,y0,x1,y1)
		local pat = cairo_pattern_create_linear (x0,y0,x1,y1)
		cairo_pattern_add_color_stop_rgba (pat, 0, to_rgba(t.fg_colour))
		cairo_pattern_add_color_stop_rgba (pat, 1, to_rgba(t.alarm_colour))
		if t.mid_colour  then
			for i=1, #t.mid_colour do
				cairo_pattern_add_color_stop_rgba (pat, t.mid_colour[i][1], to_rgba({t.mid_colour[i][2],t.mid_colour[i][3]}))
			end
		end
		return pat
	end

	local function create_smooth_radial_gradient(x0,y0,r0,x1,y1,r1)
		local pat =  cairo_pattern_create_radial (x0,y0,r0,x1,y1,r1)
		cairo_pattern_add_color_stop_rgba (pat, 0, to_rgba(t.fg_colour))
		cairo_pattern_add_color_stop_rgba (pat, 1, to_rgba(t.alarm_colour))
		if t.mid_colour  then
			for i=1, #t.mid_colour do
				cairo_pattern_add_color_stop_rgba (pat, t.mid_colour[i][1], to_rgba({t.mid_colour[i][2],t.mid_colour[i][3]}))
			end
		end
		return pat
	end

	local function create_led_linear_gradient(x0,y0,x1,y1,col_alp,col_led)
		local pat = cairo_pattern_create_linear (x0,y0,x1,y1) ---delta, 0,delta+ t.width,0)
		cairo_pattern_add_color_stop_rgba (pat, 0.0, to_rgba(col_alp))
		cairo_pattern_add_color_stop_rgba (pat, 0.5, to_rgba(col_led))
		cairo_pattern_add_color_stop_rgba (pat, 1.0, to_rgba(col_alp))
		return pat
	end

	local function create_led_radial_gradient(x0,y0,r0,x1,y1,r1,col_alp,col_led,mode)
		local pat = cairo_pattern_create_radial (x0,y0,r0,x1,y1,r1)
		if mode==3 then
			cairo_pattern_add_color_stop_rgba (pat, 0, to_rgba(col_alp))
			cairo_pattern_add_color_stop_rgba (pat, 0.5, to_rgba(col_led))
			cairo_pattern_add_color_stop_rgba (pat, 1, to_rgba(col_alp))
		else
			cairo_pattern_add_color_stop_rgba (pat, 0, to_rgba(col_led))
			cairo_pattern_add_color_stop_rgba (pat, 1, to_rgba(col_alp))
		end
		return pat
	end

	local function draw_single_bar()
		--this fucntion is used for bars with a single block (blocks=1) but
		--the drawing is cut in 3 blocks : value/alarm/background
		--not zvzimzblr for circular bar
		local function create_pattern(col_alp,col_led,bg)
			local pat

			if not t.smooth then
				if t.led_effect=="e" then
					pat = create_led_linear_gradient (-delta, 0,delta+ t.width,0,col_alp,col_led)
				elseif t.led_effect=="a" then
					pat = create_led_linear_gradient (t.width/2, 0,t.width/2,-t.height,col_alp,col_led)
				elseif  t.led_effect=="r" then
					pat = create_led_radial_gradient (t.width/2, -t.height/2, 0, t.width/2,-t.height/2,t.height/1.5,col_alp,col_led,2)
				else
					pat = cairo_pattern_create_rgba  (to_rgba(col_alp))
				end
			else
				if bg then
					pat = cairo_pattern_create_rgba  (to_rgba(t.bg_colour))
				else
					pat = create_smooth_linear_gradient(t.width/2, 0, t.width/2,-t.height)
				end
			end
			return pat
		end

		local y1=-t.height*pct/100
		local y2=nil
		if pct>(100*t.alarm/t.max) then
			y1 = -t.height*t.alarm/100
			y2 = -t.height*pct/100
			if t.smooth then y1=y2 end
		end

		if t.angle_bar==0 then

			--block for fg value
			pat = create_pattern(t.fg_colour,t.fg_led,false)
			cairo_set_source(cr,pat)
			cairo_rectangle(cr,0,0,t.width,y1)
			cairo_fill(cr)

			-- block for alarm value
			if not t.smooth and y2  then
				pat = create_pattern(t.alarm_colour,t.alarm_led,false)
				cairo_set_source(cr,pat)
				cairo_rectangle(cr,0,y1,t.width,y2-y1)
				cairo_fill(cr)
				y3=y2
			else
				y2,y3=y1,y1
			end
			-- block for bg value
			cairo_rectangle(cr,0,y2,t.width,-t.height-y3)
			pat = create_pattern(t.bg_colour,t.bg_led,true)
			cairo_set_source(cr,pat)
			cairo_pattern_destroy(pat)
			cairo_fill(cr)
		end
	end  --end single bar

	local function draw_multi_bar()
		--function used for bars with 2 or more blocks
		for pt = 1,t.blocks do
			--set block y
			local y1 = -(pt-1)*(t.height+t.space)
			local light_on=false

			--set colors
			local col_alp = t.bg_colour
			local col_led = t.bg_led
			if pct>=(100/t.blocks) or pct>0 then --ligth on or not the block
				if pct>=(pcb*(pt-1))  then
					light_on = true
					col_alp = t.fg_colour
					col_led = t.fg_led
					if pct>=(100*t.alarm/t.max) and (pcb*pt)>(100*t.alarm/t.max) then
						col_alp = t.alarm_colour
						col_led = t.alarm_led
					end
				end
			end

			--set colors
			--have to try to create gradients outside the loop ?
			local pat

			if not t.smooth then
				if t.angle_bar==0 then
					if t.led_effect=="e" then
						pat = create_led_linear_gradient (-delta, 0,delta+ t.width,0,col_alp,col_led)
					elseif t.led_effect=="a" then
						pat = create_led_linear_gradient (t.width/2, -t.height/2+y1,t.width/2,0+t.height/2+y1,col_alp,col_led)
					elseif  t.led_effect=="r" then
						pat = create_led_radial_gradient (t.width/2, y1, 0, t.width/2,y1,t.width/1.5,col_alp,col_led,2)
					else
						pat = cairo_pattern_create_rgba  (to_rgba(col_alp))
					end
				else
					 if t.led_effect=="a"  then
						 pat = create_led_radial_gradient (0, 0, t.radius+(t.height+t.space)*(pt-1), 0, 0, t.radius+(t.height+t.space)*(pt), col_alp,col_led,3)
					else
						pat = cairo_pattern_create_rgba  (to_rgba(col_alp))
					end

				end
			else

				if light_on then
					if t.angle_bar==0 then
						pat = create_smooth_linear_gradient(t.width/2, t.height/2, t.width/2,-(t.blocks-0.5)*(t.height+t.space))
					else
						pat = create_smooth_radial_gradient(0, 0, (t.height+t.space),  0,0,(t.blocks+1)*(t.height+t.space),2)
					end
				else
					pat = cairo_pattern_create_rgba  (to_rgba(t.bg_colour))
				end
			end
			cairo_set_source (cr, pat)
			cairo_pattern_destroy(pat)

			--draw a block
			if t.angle_bar==0 then
				cairo_move_to(cr,0,y1)
				cairo_line_to(cr,t.width,y1)
			else
				cairo_arc( cr,0,0,
					t.radius+(t.height+t.space)*(pt)-t.height/2,
					 -t.angle_bar -PI/2 ,
					 t.angle_bar -PI/2)
			end
			cairo_stroke(cr)
		end
	end

	local function setup_bar_graph()
		--function used to retrieve the value to display and to set the cairo structure
		if t.blocks ~= 1 then t.y=t.y-t.height/2 end

		local value = 0
		if t.name ~="" then
		-- ${lua main bargraph 117 275 90 3 cpu cpu1}
			value = tonum(conky_parse(sprintf('${%s %s}', t.name, t.arg)))
		else
			value = tonum(t.arg)
		end

		if value==nil then value =0 end

		pct = 100*value/t.max
		pcb = 100/t.blocks

		cairo_set_line_width (cr, t.height)
		cairo_set_line_cap  (cr, cap)
		cairo_translate(cr,t.x,t.y)
		-- -- Edit by Paramvir - this corrects the wrong start of alarm colour
		-- -- for angle = 90 and above
		-- -- There is however still an issue between 20 to 89 degrees
		cairo_rotate(cr,(t.angle+.0000001))

		local matrix0 = cairo_matrix_t:create()
		cairo_matrix_init (matrix0, 1,t.skew_y,t.skew_x,1,0,0)
		cairo_transform(cr,matrix0)



		--call the drawing function for blocks
		if t.blocks==1 and t.angle_bar==0 then
			draw_single_bar()
			if t.reflection=="t" or t.reflection=="b" then cairo_translate(cr,0,-t.height) end
		else
			draw_multi_bar()
		end

		--dot for reminder
		--[[
		if t.blocks ~=1 then
			cairo_set_source_rgba(cr,1,0,0,1)
			cairo_arc(cr,0,t.height/2,3,0,2*PI)
			cairo_fill(cr)
		else
			cairo_set_source_rgba(cr,1,0,0,1)
			cairo_arc(cr,0,0,3,0,2*PI)
			cairo_fill(cr)
		end
	]]
		--call the drawing function for reflection and prepare the mask used
		if t.reflection_alpha>0 and t.angle_bar==0 then
			local pat2
			local matrix1 = cairo_matrix_t:create()
			if t.angle_bar==0 then
				pts={-delta/2,(t.height+t.space)/2,t.width+delta,-(t.height+t.space)*(t.blocks)}
				if t.reflection=="t" then
					cairo_matrix_init (matrix1,1,0,0,-t.reflection_scale,0,-(t.height+t.space)*(t.blocks-0.5)*2*(t.reflection_scale+1)/2)
					pat2 = cairo_pattern_create_linear (t.width/2,-(t.height+t.space)*(t.blocks),t.width/2,(t.height+t.space)/2)
				elseif t.reflection=="r" then
					cairo_matrix_init (matrix1,-t.reflection_scale,0,0,1,delta+2*t.width,0)
					pat2 = cairo_pattern_create_linear (delta/2+t.width,0,-delta/2,0)
				elseif t.reflection=="l" then
					cairo_matrix_init (matrix1,-t.reflection_scale,0,0,1,-delta,0)
					pat2 = cairo_pattern_create_linear (-delta/2,0,delta/2+t.width,-0)
				else --bottom
					cairo_matrix_init (matrix1,1,0,0,-1*t.reflection_scale,0,(t.height+t.space)*(t.reflection_scale+1)/2)
					pat2 = cairo_pattern_create_linear (t.width/2,(t.height+t.space)/2,t.width/2,-(t.height+t.space)*(t.blocks))
				end
			end
			cairo_transform(cr,matrix1)

			if t.blocks==1 and t.angle_bar==0 then
				draw_single_bar()
				cairo_translate(cr,0,-t.height/2)
			else
				draw_multi_bar()
			end


			cairo_set_line_width(cr,0.01)
			cairo_pattern_add_color_stop_rgba (pat2, 0,0,0,0,1-t.reflection_alpha)
			cairo_pattern_add_color_stop_rgba (pat2, t.reflection_length,0,0,0,1)
			if t.angle_bar==0 then
				cairo_rectangle(cr,pts[1],pts[2],pts[3],pts[4])
			end
			cairo_clip_preserve(cr)
			cairo_set_operator(cr,CAIRO_OPERATOR_CLEAR)
			cairo_stroke(cr)
			cairo_mask(cr,pat2)
			cairo_pattern_destroy(pat2)
			cairo_set_operator(cr,CAIRO_OPERATOR_OVER)

		end --reflection


	end --setup_bar_graph()


	--start here !
	setup_bar_graph()
	cairo_restore(cr)
end		------------ }}}


----------------------------------------------------------------------
local function do_barometer(vala)		------------ {{{
	--baromeer 27 inches to 32 inches = 5 inches
	-- 2014 - Paramvir conkywx scalable with temperature

	local px        	 	= tonum(vala.lwx) 	or 200
	local py        	 	= tonum(vala.lwy) 	or 200
	local baro_size_real 	= tonum(vala.s) 		or 200
	local pr 			 	= vala.r 				or 27.75
	local bunit    		 	= vala.u 				or "C"
	-- local baro_colour 		= vala.c			or tconcat({MidnightBlue,":0.75"})
	-- local text_colour		= vala.e			or tconcat({Gold,":1"})
	-- local arrow_colour		= vala.x			or tconcat({Orange,":1"})
	local baro_colour 		= vala.c				or tconcat({DarkLime,':1'})
	local text_colour		= vala.e				or tconcat({NavyBlue,':1'})
	local arrow_colour		= vala.x				or tconcat({Orange,':1'})
	local bimage			= vala.j				or nil
	-- bimage=1

	if tonum(bimage) == 0 then bimage = nil end

	baro_colour  = wxsplit(baro_colour,":")
	text_colour  = wxsplit(text_colour,":")
	arrow_colour = wxsplit(arrow_colour,":")
	-- print(arrow_colour[1])


	local prfact=0.02953

	local bstart_scale=180
	local bend_scale=275

	-- internal size
	baro_size_real = baro_size_real * 1.035
	local baro_size=(baro_size_real/2)
	-- local baro_size=40

	-- pr='11 h'
	-- pr='1977 h'
	-- pr=nil
	-- bunit='F'
	-- print(pr)
	-- local wxx1 = pr:match("(%d+%.?%d%d?)")
	local wxx1 = pr:match('([%d%.]+)')
	if wxx1 == 0 or not wxx1 then
		pr=0
	else
		pr=tonum(wxx1)
	end
		-- print(pr,bunit)
	if bunit == "C" then pr = pr * prfact end
	if pr < 10 or pr > 34 then pr = 0 end

	------#########################################
	-- pr = 11
	-- bunit="F"
	------#########################################
	-- print(pr/prfact)

	-- print(pr)

	px = px + (baro_size_real*0.5) + 5
	py = py + (baro_size_real*0.5) + 1


	-- local bimages = nil
	-- if bimage == "NA" and file1 ~= "NA" then
	if not bimage or bimage == "NA" then
		bimages = baro_size_real; baro_size = baro_size_real * 0.48
	else
		bimages = baro_size_real; baro_size = baro_size_real * 0.448
	end

	if tonum(bimage) == 2 then
		cairo_save(cr)
		make_bezel({ bezel_size = baro_size_real, px = px, py = py })
		cairo_restore(cr)
	end

	local fsize1

	if baro_size < 75 then
		fsize1 = 7.5; modfactor=20
		if baro_size < 41 then
			hpafact=10; pointer_size=(baro_size/9); brfact={.3,.2}
		else
			hpafact=1; pointer_size=(baro_size/12); brfact={.7,.5}
		end
	else
		fsize1 = baro_size/8.9; modfactor=10
		hpafact=1; pointer_size=(baro_size/14); brfact={1,1}
	end

	cairo_save(cr)
	set_font(tconcat({'normal:',fsize1}))

	cairo_set_line_width (cr,1)
	cairo_set_source_rgba (cr, to_rgba(baro_colour))
	cairo_arc (cr,px,py,baro_size,TORADIANS,0)
	cairo_fill (cr)
	cairo_set_source_rgba (cr, to_rgba(text_colour))

	if    pr >= 10 and pr <= 13 then  startin=9.5;crf=0 ;crf2=0 ;icf_lt=0 ;icf_rt=-1
	elseif pr > 13 and pr <= 16 then startin=12.5;crf=2 ;crf2=0.25 ;icf_lt=3 ;icf_rt=0
	elseif pr > 16 and pr <= 19 then startin=15.5;crf=3 ;crf2=0 ;icf_lt=7 ;icf_rt=0
	elseif pr > 19 and pr <= 22 then startin=18.5;crf=-5;crf2=-1;icf_lt=-11;icf_rt=0
	elseif pr > 22 and pr <= 25 then startin=21.5;crf=-4;crf2=0 ;icf_lt=-9;icf_rt=0
	elseif pr > 25 and pr <= 28 then startin=24.5;crf=-2;crf2=-2;icf_lt=-3;icf_rt=-3
	elseif pr > 28 and pr <= 31 then startin=27.5;crf=0 ;crf2=-1;icf_lt=-1;icf_rt=0
	elseif pr > 31 and pr <= 34 then startin=30.5;crf=1 ;crf2=1 ;icf_lt=1 ;icf_rt=3
	else startin = 27.55; crf=0;crf2=0 ;icf_lt=0 ;icf_rt=0
	end
	local starthpa=floor((startin/prfact)+(8.75-crf))
	local inch_out=baro_size/2.3, itext
	-- set thickness of inch scale
	local inch_thickness=inch_out-(baro_size/11.5)
	-- local rout=inch_out-(baro_size/7.66666667)

	for i=0,30 do
		if (i%5==0) then
			rini=inch_thickness+(baro_size/57.5)
			cairo_set_line_width (cr,brfact[1])
		else
			-- print(i)
			rini=inch_thickness+(baro_size/23)
			cairo_set_line_width (cr,brfact[2])
		end
		cairo_save(cr)
		make_scale_txt2({
			startscale	= bstart_scale+20+icf_lt,
			endscale	= bend_scale-42+icf_rt,
			maxscale	= 30,
			rout		= inch_out,
			rin			= rini,
			xval		= px,
			yval		= py,
			i			= i		})
	end
	for i=1,4 do
		if pr == 0 then
			itext = 0
		else
			itext = (startin-0.5)+i
		end
		-- tinsert(inch, (startin-0.5)+i)
		make_scale_txt2({
			startscale	= bstart_scale+(bend_scale/14)+icf_lt,
			endscale	= bend_scale/3.5+icf_rt,
			maxscale	= 1,
			-- trout       = rout*0.93,
			trout       = inch_out*0.65,
			text        = itext,
			ifact       = 1,
			dotext      = 1,
			xval		= px,
			yval		= py,
			text		= itext,
			i			= i-1	})
	end
	--942 to 1056
	--27.5=931.25
	--31.5=1066.70 -- 1066.70-931.25 = 135.45
	cairo_set_line_width (cr,1)
	local mb_out=baro_size/2.1
	local textcorrn = 1
	local mb_thickness=mb_out-textcorrn
	-- local mb_thickness=mb_out-25
	local num=120

	if modfactor == 10 then
		rout=mb_thickness+(baro_size/4.79166667)
	else
		rout=mb_out+(baro_size/4)
	end
	-- set thicknesses of millibar scale
	-- for i=0,num do
	for i=0,num do
		local mb1
		if (i%10==0) then
			rinm=mb_out+(baro_size/11.5) --10
			cairo_set_line_width (cr,brfact[1])
		elseif (i%2 == 0) then
			rinm=mb_out+(baro_size/23) --5
			cairo_set_line_width (cr,brfact[2])
		else
			cairo_set_line_width (cr,0)
		end
		if (i%modfactor==0) then
			if pr == 0 then
				mb1 = 0
			else
				mb1 = (starthpa + i)/hpafact
			end
			-- print(i,modfactor,inc1,hpafact,starthpa)
		end

		cairo_save(cr)
		make_scale_txt2({
			startscale	= bstart_scale,
			endscale	= bend_scale,
			maxscale	= num,
			rout		= mb_out,
			trout       = mb_out*1.5,
			-- trout       = mb_out*.95,
			text        = mb1,
			ifact       = 1,
			rin			= rinm,
			xval		= px,
			yval		= py,
			i			= i		})
	end
	--millibars reading
	cairo_save(cr)
	local itext, mtext, py1
	if baro_size < 41 then
		make_txt({ text="x10", px=px, py=py+rini+2 })
		itext=" "
		mtext=" "
	elseif modfactor == 10 then
		itext="inches"
		mtext="millibars"
	else
		itext="in"
		mtext="mb"
	end

	--scale labels
	cairo_save(cr)
	make_txt({ text=itext, px=px+10, py=py+rini+7, align='l' })
	make_txt({ text=mtext, px=px+10, py=py+rinm+3, align='l' })

	if modfactor == 10 then
		set_font('bold:13')
		mtext="Barometer"
		py1=0
	else
		set_font('bold:13')
		mtext="Baro"
		py1=3
	end
	make_txt({ text=mtext, px=px+11, py=py+(rini*0.75)+py1, align='l' })
	local pres=pr-(startin+0.5)
	---- indicator arrows
	cairo_save(cr)
	choose_indicator({
		startval= bstart_scale+20+icf_lt,
		scale	= pres*((bend_scale-42)/3)+crf2,
		rout1	= mb_out+5,
		cthick  = pointer_size*0.5,
		ch_indi = tonum(vala.a) or 6,
		px		= px,
		py		= py,
		icolour = arrow_colour,
	})

	cairo_set_source_rgba (cr, to_rgba(text_colour))
	cairo_save(cr)
	local fsize=baro_size/10.45454545
	-- if modfactor == 10 then
	if baro_size > 65 then
		set_font(tconcat({'normal:',fsize}))
		local bring_labels = { 'STORM','RAIN','CHANGE','FAIR','VERY DRY'}
		for i=1, 5 do
			local start = bstart_scale+10
			if i > 1 then start = (start-55)+(55*i) end
			local finish=start+((string.len(bring_labels[i]))*5)
			circlewriting2(bring_labels[i], baro_size/1.15, px, py, start, finish)
		end
	end

	if tonum(bimage) == 1 then
		cairo_save(cr)
		instrument_sqr({routI=bimages, wx=px, wy=py})
	end
end--barometer		------------ }}}

local function do_anemometer(vala)		------------ {{{
-------------------------------------------
	-- scalable version 2014 Paramvir
	-- change this value and the rest of the dial changes
	local max_scale_mph = 60

	---need to fix the magnification options router
-------------------------------------------
	--0 to 80 mph
	local px 	= vala.lwx+(vala.s/2)+1
	local py 	= vala.lwy+(vala.s/2)+5
	local wsdial_size_actual=vala.s
	local ws 	= vala.r
	local wg 	= vala.t or 0.01
	local u1 	= vala.u
	-- local wvar  = vala.wvariance
	-- local wdeg  = vala.d or 0
	local wvane = tonum(vala.w)
	local bimage = vala.j				or nil
	-- bimage=1

	if tonum(bimage) == 0 then bimage = nil end

	-------------------- c-lour
	local dial_colour1 		= vala.c				or tconcat({DarkLime,":1"})
	local text_colour1		= vala.e				or tconcat({NavyBlue,":1"})
	local arrow_colour1		= vala.x				or tconcat({Orange,":1"})

	local dial_colour  = wxsplit(dial_colour1,":")
	local text_colour  = wxsplit(text_colour1,":")
	local arrow_colour = wxsplit(arrow_colour1,":")
	-- local astart_scale  = 210
	-- local aend_scale    = 300
	local astart_scale  = 180
	local aend_scale    = 275
	local random_seed   = 0
	local kmh_mph_fact  = 0.62137119

	local seedval=nil
	local updateint = tonum(conky_info.update_interval)
	local updates = tonum(conky_parse("${updates}"))
	if updateint < 3 then seedval = 5 else seedval = 2 end
	local wvar = (( updates % seedval)+1)
	-- if wvariance == 1 then wvariance = 999 end


	-- ws='windstill'
	-- print(ws:match("(%d+%.?%d?)"))

	-- ws='30.5 km/h'
	-- wind speed ws
	-- local wxx3 = ws:match("(%d+%.?%d?)")
	local wxx3 = ws:match('([%d%.]+)')
	if wxx3 == 0 or not wxx3 then
		ws = 0
	else
		ws=tonum(wxx3)
		if u1 == "C" then ws = ws * kmh_mph_fact end
		if ws <= 60 then
			max_scale_mph = 70
		else
			for i=60,300 do
				if ws > i and (i%10==0) then max_scale_mph = i+20 end
			end
		end
	end
	-- -- wind gust wg
	-- local wxx1 = wg:match("(%d+%.?%d?)")
	local wxx1 = wg:match('([%d%.]+)')
	if wxx1 == 0 or not wxx1 then
		wg = 0
	else
		wg = tonum(wxx1)
		if u1 == "C" then wg = wg * kmh_mph_fact end
	end
	-- print(ws)

	wsdial_size_actual = wsdial_size_actual * 1.035
	local wsdial_size=wsdial_size_actual/2

	-- local bimages = nil
	if not bimage or bimage == "NA" then
		bimages = wsdial_size_actual; wsdial_size = wsdial_size_actual * 0.48
	else
		bimages = wsdial_size_actual; wsdial_size = wsdial_size_actual * 0.448
	end

	if tonum(bimage) == 2 then
		cairo_save(cr)
		make_bezel({ bezel_size = wsdial_size_actual, px = px, py = py })
		cairo_restore(cr)
	end

	local fsizeA = nil
	local pointer_size = nil
	local illumfact = {}
	local wstxt, wstxt2, anem_fact

	-- cairo_save(cr)
	if wsdial_size < 65 then
		if max_scale_mph < 120 then
			fsizeA = 8; kntxt="kn"; wstxt2="x10"
			illumfact={0.6,0.2,0.2}; txtfact1=10;cfact=10
			pointer_size=(wsdial_size/9)
		elseif max_scale_mph < 220 then
			fsizeA = 8; kntxt="kn"; wstxt2="x10"
			illumfact={0.5,0.2,0.1}; txtfact1=10;cfact=20
			pointer_size=(wsdial_size/9)
		else
			fsizeA = 8; kntxt="kn"; wstxt2="x10"
			illumfact={0.5,0.1,0.1}; txtfact1=10;cfact=30
			pointer_size=(wsdial_size/9)
		end
		wstxt='';
	else
		if max_scale_mph < 120 then
			illumfact={1.7,0.5,0.5}; txtfact1=1; cfact=10
		elseif max_scale_mph < 160 then
			illumfact={0.6,0.2,0.2}; txtfact1=10; cfact=10
		else
			illumfact={0.6,0.2,0.2}; txtfact1=10; cfact=20
		end
		-- wstxt="Anemometer"
		fsizeA = (wsdial_size/8.8)
		kntxt="knots"
		pointer_size=(wsdial_size/14)
	end

	cairo_save(cr)
	set_font(tconcat({"Mono:",fsizeA}))

	cairo_set_line_width(cr,1)
	cairo_set_source_rgba(cr,to_rgba(dial_colour))
	cairo_arc(cr,px,py,wsdial_size,TORADIANS,0)
	cairo_fill(cr)
	-- cairo_save(cr)
	cairo_set_source_rgba(cr,to_rgba(text_colour))
	-- cairo_arc (cr,px,py,wsdial_size,TORADIANS,0)
	-- cairo_stroke (cr)
	-------------------------------------------

	-- settings at wsdial_size = 100
	-- distance from center
	local mph_out=wsdial_size*0.69 -- 73% of dial size
	-- mph line thickness
	local mph_thickness=mph_out*0.93 -- 93% of the outer ring edge
	local mph, kmh, knot = {}, {}, {}
	local mtext
	for i=0,max_scale_mph do
		if (i%5==0) and (i%10~=0) then
			rin=mph_thickness*0.95 --set line length for 5s
			cairo_set_line_width (cr,illumfact[2])
		elseif (i%10==0) then
			if (i%cfact==0) then
				-- tinsert(mph, i/txtfact1)
				mtext = i/txtfact1
			end
			rin=mph_thickness--set line length for 10's
			cairo_set_line_width (cr,illumfact[1])
		else
			rin=mph_thickness --set other lines
			cairo_set_line_width (cr,illumfact[3])
		end
		cairo_save(cr)
		make_scale_txt2({
			startscale	= astart_scale,
			endscale	= aend_scale,
			maxscale	= max_scale_mph,
			rout		= mph_out,
			trout       = mph_out*0.82,
			text        = mtext,
			ifact       = cfact,
			rin			= rin,
			xval		= px,
			yval		= py,
			i			= i	})
	end--

	--kmh lines and numbers
	local scale_kmh = max_scale_mph / kmh_mph_fact
	cairo_set_line_width(cr,1)
	local kmh_out=wsdial_size*.72 -- ring located at 82%
	local kmh_thickness=kmh_out*1.065 --5
	local ktext
	-- kmh={}-----------------------------------------------
	for i=0,scale_kmh do
		if (i%10==0) then
			if (i%cfact==0) then
				-- tinsert(kmh, i/txtfact1)
				kmh[#kmh+1] = i/txtfact1
				ktext = i/txtfact1
			end
			rin=kmh_thickness--set length for 10s
			cairo_set_line_width (cr,illumfact[1])
		elseif (i%5==0) and (i%10~=0) then
			rin=kmh_thickness*1.05 --set length for 5's
			cairo_set_line_width (cr,illumfact[2])
		else
			rin=kmh_thickness
			cairo_set_line_width (cr,illumfact[3])
		end
		---------------------------------------------------
		cairo_save(cr)
		make_scale_txt2({
			startscale	= astart_scale,
			endscale	= aend_scale,
			maxscale	= scale_kmh,
			rout		= kmh_out,
			trout       = kmh_out*1.23,
			text        = ktext,
			ifact       = cfact,
			rin			= rin,
			xval		= px,
			yval		= py,
			i			= i	})

	end
	--knots--------------------------------------------------
	local scale_knots = max_scale_mph * 0.86897624
	cairo_set_line_width (cr,1)
	local kn_out=wsdial_size*0.47
	local kn_thickness=kn_out*0.9
	local kntext
	-- knot={}
	if wvane ~= 1 then
		for i=0,scale_knots do
			if (i%cfact==0) then
				-- tinsert(knot,i/txtfact1)
				kntext = i/txtfact1
				-- print(cfact)
				rin=kn_thickness--set length for 10s
				cairo_set_line_width (cr, illumfact[1])
			elseif (i%(cfact/2)==0) and (i%cfact~=0) then
				rin=kn_thickness*0.95--set length for 5's
				cairo_set_line_width (cr, illumfact[2])
			else
				rin=kn_thickness
				cairo_set_line_width (cr, illumfact[3])
			end
			---------------------------------------------------
			cairo_save(cr)
			-- print(cfact)
			make_scale_txt2({
				startscale	= astart_scale,
				endscale	= aend_scale,
				maxscale	= scale_knots,
				rout		= kn_out,
				trout		= kn_out*0.72,
				text        = kntext,
				ifact       = cfact,
				rin			= rin,
				xval		= px,
				yval		= py,
				i			= i	})
		end
	end

	-- print(wsdial_size)
	if wsdial_size > 88 then
		set_font(tconcat({'bold:',13}))
		wstxt="Anemometer"
	else
		set_font(tconcat({'bold:',11}))
		wstxt="Anemo"
	end
	make_txt({ text=wstxt, px=px+7, py=py+(kn_thickness*0.6), align='l' })
	-- text output names
	if wsdial_size > 40 then
	-- if wsdial_size > 65 then
		cairo_save(cr)
		set_font(tconcat({'normal:',fsizeA}))
		make_txt({ text=kntxt, px=px+7, py=py+kn_thickness,       align='l' })
		make_txt({ text='mph', px=px+7, py=py+mph_thickness,       align='l' })
		make_txt({ text='kmh', px=px+7, py=py+(kmh_thickness*1.1), align='l' })
		-- set_font('bold'..fsizeA)
		if wstxt2 then
			make_txt({ text=wstxt2, px=px+23, py=py+(kn_thickness*1.0), align='l' })
		end
	else
		cairo_save(cr)
		make_txt({ text=wstxt, px=px, py=py+kmh_thickness })
	end


	local seed_factor_h = 0
	local seed_factor_l = 0
	if ws ~= 0 then
		if wg and wg > ws then
			seed_factor_h = wg + 2
			seed_factor_l = ws - 2
		else
			seed_factor_h = ws + 3
			seed_factor_l = ws - 3
		end
	else
		seed_factor_h = nil
		seed_factor_l = nil
	end


	local wspd = 0
	if ws < max_scale_mph then
		if wvar == 1 and seed_factor_h then
			random_seed=random(seed_factor_l,seed_factor_h)
		else
			random_seed=0
		end

		if random_seed <= 0 then random_seed = ws
		elseif random_seed > max_scale_mph then random_seed = max_scale_mph
		end

		wspd = random_seed
	else wspd = max_scale_mph
	end

	local indicator_range=aend_scale/max_scale_mph
	cairo_save(cr)
	choose_indicator({
		startval= astart_scale,
		scale	= wspd * indicator_range,
		rout1	= kmh_out*1.11,
		cthick  = pointer_size*0.65,
		px		= px,
		py		= py,
		ch_indi = tonum(vala.a) or 6,
		icolour = arrow_colour,
	})
-- print(vala.i)
	if wvane == 1 then
		local w_vane = {
			lwx    	 = px,
			-- lwx    	 = vala.lwx,
			lwy	  	 = py,
			-- lwy	  	 = vala.lwy,
			s  		 = (wsdial_size*0.95),
			d  		 = vala.d,
			i  		 = vala.i or "NA",
			a 		 = vala.a or "NA",
			-- l        = vala.l or Red,
			l        = vala.l or tconcat({Red,":0.7"}),
			wvariance = vala.wvariance,
			imgpath  = vala.imgpath,
			nring 	 = 1
		}
		do_windvane(w_vane)
	end

	if tonum(bimage) == 1 then
		cairo_save(cr)
		instrument_sqr({routI=bimages, wx=px, wy=py})
	end

	-- -- end
end--anemometer function		------------ }}}


----------------------------------------------------------------------
local function bargraph_styles(p)		------------ {{{
--  by paramvir - 2014
	local bar_style =tonum(p.s)
	local val1 = p.lwx
	local val2 = p.lwy
	local val7 = p.l
	local val8 = p.x
	-- local fgcol = p.c

	-- print(p.e)
	-- -- the styles match the 100 pixel value criteria - easier to place in conky
	-- -- bar_width in pixels
	-- -- thin dashes
	local bar_width =tonum(p.w)
	if bar_style == 1 then
		b_height = 6; b_width = 2.5; b_space = 2
		b_blocks = (bar_width/(b_height+b_space))
	-- -- thick dashes
	elseif bar_style == 2 then
		b_height = 6; b_width = 5; b_space = 2
		b_blocks = (bar_width/(b_height+b_space))
		val2=val2-(b_width/2)
	-- -- spaced vertical bars
	elseif bar_style == 3 then
		b_height = 2; b_width = 6; b_space = 2;
		b_blocks = (bar_width/(b_height+b_space))
		val1 = val1-2; val2 = val2-(b_width/1.5)
	-- -- closer spaced vertical bars
	elseif bar_style == 4 then
		b_height = 2; b_width = 6; b_space = 1;
		s_blocks = (bar_width/(b_height+b_space))
		-- b_blocks = (bar_width-s_blocks)
		b_blocks = s_blocks
		val1 = val1-2; val2=val2-(b_width/1.5)
	-- -- smooth single bar without vertical slots
	elseif bar_style == 5 then
		b_blocks = 1
		bar_offset = 3
		b_height = bar_width-bar_offset; b_width=6
		val1 = val1-bar_offset; val2=val2-(b_width/1.2)
	end
	if tonum(val7) == 1 then
		bar_led_effect = true
		bar_alarm_value = tonum(val8) or bar_alarm_value
	else
		bar_led_effect = false
		val7 = nil
	end
	-- bar_led_effect1 == bar_led_effect or val7 or nil
	if bar_led_effect == true then
		b_smooth = false
		alarm_led=bar_alarm_colour
	else
		b_smooth = true
	end
	local bars_settings={
		name         = p.f,
		arg          = p.a,
		x            = val1,
		y            = val2,
		max          = bar_max_value,
		alarm        = bar_alarm_value,
		alarm_colour = p.c or bar_alarm_colour,
		bg_colour    = bar_bg_colour,
		fg_colour    = p.e or bar_fg_colour,
		mid_colour   = p.d or bar_mid_colour,
		blocks       = b_blocks,
		space        = b_space,
		height       = b_height,
		width        = b_width,
		angle        = bar_angle_value,
		smooth       = b_smooth,
		-- led_effect   = bar_led_effect_alarm
		led_effect   = "r"
	}
	do_bargraph(bars_settings)

end			--------------- }}}

local function do_scroller(vala)		-----{{{
-- by paramvir 2014
	local grplen        = tonum(vala.l) 		or 36 ---- text length l
	local stepval1      = tonum(vala.s) 		or 1 ---- text stepping s
	local drc           = vala.w 	or	"B" 	-- d
	local lpx           = tonum(vala.lwx) 	or 50
	local lpy           = tonum(vala.lwy) 	or 250			-- p
	local jumpinc       = tonum(vala.i)		or 10			-- v
	local range         = tonum(vala.r)		or 0		-- r
	local fileA         = vala.o				-- or "NA"
	local mdata         = vala.d				or " "
	local show_block    = vala.b               or '0'
	local align_text    = vala.a	           or 'l'
	local h_light       = vala.h               or tconcat({Yellow,':1'})
	local alt_h_light   = vala.g               or tconcat({Orchid1,':1'})
	local sccolour 	    = vala.c               or '0x00c0ff:1'
	local mcolour       = wxsplit(sccolour,":")
	cairo_set_source_rgba (cr,to_rgba(mcolour))

	drc = string.upper(drc)

	local updates = tonum(conky_parse("${updates}"))
	local f_check = updates % 2
	-- print(mdata)

	cairo_save(cr)
	set_font(vala.f)

	-- if a string is input with new line characters they get cleaned with pipe characters.
	if vala.d then mdata = string.gsub(vala.d,":::","| ") end

	if vala.o then
		fileA = string.gsub(fileA,"\n","")
	else
		fileA = "NA"
	end

	if show_block:find('::') then
		local shblk = wxsplit(show_block,'::')
		show_block = tonum(shblk[1])
		bgcolour   = shblk[2]
	else
		show_block = tonum(show_block)
		bgcolour   = nil
	end

	local rdata2={}
	if fileA ~= "NA" then
		local idata = ExecInfo({ rfile = fileA })
		if idata then
			local line = wxsplit(idata,'\n')
			for d = 1, #line do
				if show_block >= 1 then
					rdata2[#rdata2+1] = line[d]
				else
					rdata2[#rdata2+1] = tconcat({line[d],' | '})
				end
			end
		end
		mdata = tconcat(rdata2, "\n" )
		mdata = string.gsub(mdata, "\n", "")
	end

	local ww = conky_window.width
	local wh = conky_window.height
	if lpy > wh then lpy=wh
	elseif lpy < 0 then lpy = 0 end
	local lineposn=lpy

	if show_block == 0 then
		local stepval = abs(stepval1)

		local txtlen=#mdata
		local gettxt1
		local gettxt2
		local gettxt3
		local timer = ((updates % txtlen) + 1)
		local sv = stepval+3

		if txtlen > grplen then
			for i=1,txtlen do
				local gettxt1=string.rep(mdata,sv)
				if timer == i then
					local l=i*stepval
					if stepval1 > 0 then
						local gettxt2=string.sub(gettxt1,l)
						gettxt3=string.sub(gettxt2,1,grplen)
					elseif stepval1 < 0 then
						local gettxt2=string.sub(gettxt1,-#gettxt1,-l)
						gettxt3=string.sub(gettxt2,-grplen,-1)
					end
				end
				gettxt1=" "
			end
		else
			gettxt3=string.sub(mdata,1,-3)
		end
		-- print(gettxt3)


		local srange = range/2
		local minrange = lpy-srange
		if minrange<=0 then
			minrange=10
			range=srange+lpy
		end
		local maxrange = lpy+srange
		if maxrange>=wh then
			maxrange=(wh-jumpinc)
			range=srange+((lpy+srange+jumpinc)-wh)
		end
		local startpt = maxrange

		local timerval = (floor(range/jumpinc)-1)
		local timer2 = ((updates % timerval) + 1)
		local l = 0
		if range > 0 then
			if range > l then l = range end
			for i=1, wh do
				if l > 0 then
					if timer2 == i then
						l=i*jumpinc
						if drc=="B" then
							if i == 1 and j==1 or j==nil then
								j=2
							elseif i == 1 and j==2 then
								j=1
							end
							if j == 1 then startpt=minrange+l --- down
							elseif j == 2 then startpt=(maxrange+jumpinc)-l  --- up
							end
						elseif drc=="U" then
							startpt=(maxrange+jumpinc)-l  --- up
						elseif drc=="D" then
							startpt=minrange+l --- down
						end
						if startpt < minrange then startpt=minrange
						elseif startpt > maxrange then startpt=maxrange end
					end
				end
				lineposn=startpt or lpy
				-- if not lineposn then lineposn=lpy end
			end
		end
		-- print(gettxt3)
		make_txt({
			text	= gettxt3,
			px		= lpx,
			py		= lineposn,
			align	= align_text,
			icolour	= mcolour,
		})
	end
	-- show_block = 1
	-- local win = {}
	-- local text_block_ht
	cairo_save(cr)
	if show_block >= 1 then
		local inum = 1
		local blen = #rdata2
		local mtxt, i
		-- local lineposn = 0
		if blen and blen > 0 then
			-- set background and widget poition
			if show_block == 3 or show_block == 4 then
				local extents=cairo_text_extents_t:create()
				cairo_text_extents(cr,rdata2[2],extents)
				local text_block_ht = (Global_Font_Size*blen)+extents.height
				local winy = conky_window.height
				if show_block == 3 then
					lineposn = lpy+((winy-lpy)-text_block_ht)+12
				else
					lineposn = conky_window.text_start_y+12
				end
				local bgposn = tconcat({(lpx-5),',',lineposn-Global_Font_Size-3})
				local bgsize = tconcat({(extents.width+12),',',text_block_ht})
				do_background ({
					r = 25,
					c = bgcolour or '0x333333:0.6',
					s = bgsize,
					p = bgposn,
				})
			end

			for i = 1, blen do
				mtxt = nil
				if i == 1 then
					mtxt  = rdata2[i]
				end
				if rdata2[i]:find('day') then
					mtxt  = rdata2[i]
					inum = 0
				else
					if show_block == 2 then
						inum = inum + 1
						if inum == 1 or inum == 3 then
							if  rdata2[i+1] and
								not rdata2[i+1]:find('day') then
								mtxt  = tconcat({rdata2[i]," ",rdata2[i+1]})
							else
								mtxt  = rdata2[i]
							end
						end
					else
						mtxt  = rdata2[i]
					end
				end

				-- DONE if mag > 7 then flashing colour [Tommy]
				if h_light and h_light ~= '0' and mtxt then
					mcolour = nil
					if mtxt:find('@',1,true) then
						if f_check == 0 then
							mcolour = wxsplit(h_light,":")
							mcolour = {mcolour[1],0.45}
						else
							mcolour = wxsplit(h_light,":")
						end
						mtxt = mtxt:gsub('%@%*','*')
						mtxt = mtxt:gsub('%@',' ')
					elseif mtxt:find('>',1,true) then
						mcolour = wxsplit(h_light,":")
					elseif mtxt:find('*',1,true) then
						mcolour = wxsplit(alt_h_light,":")
					elseif not mcolour then
						mcolour = wxsplit(sccolour,":")
					end
				end

				cairo_save(cr)
				if mtxt then
					lineposn = lineposn + Global_Font_Size + 0
					make_txt({
						text	= mtxt,
						px		= lpx,
						py		= lineposn-Global_Font_Size,
						align	= align_text,
						icolour	= mcolour,
						block   = 1,
					})
				end
				cairo_save(cr)
			end
		end
	end
	-- print(mdata)
	-- make_txt({ text=gettxt3, px=lpx, py=lpy, align="L" })
	-- make_txt({ text=gettxt3, px=50, py=480, align="L" })

end-------- -- }}}

-- local audnow = { 'c_min','c_sec','meta','c_kbt','c_khz','c_chl','t_fnm','astat','progress', }

local werdone          -- required for mplayer stuff
local shfl_loop_label  -- required for mplayer stuff
local loop_times       -- required for mplayer stuff
local lr = lr or 0     -- required for mplayer stuff
local ctrack
local tpt
local total_lines
local curr_aud

local function do_music_sort(p) --- --{{{

	local player     = slower(p.m)   or 'noplayer'
	local time_to_go = tonumber(p.t) or 0

	local mdata
	local audnow = {}
------ 2015 paramvir

	p.c = p.c or tconcat({Yellow,':1'}) -- for scroller call
	local aud_tt = 0
	if player ~= 'mplayer' then
		ctrack = nil
		werdone = nil
		shfl_loop_label = nil
		loop_times = nil
		lr  = nil
	elseif player ~= 'audacious' then
		curr_aud = nil
	end

	if p.d and p.d ~= '0' then p.d = 1 else p.d = nil end

	local function getVolume()
		local pvt = { '\"Master\"', '\"Master Surround\"' }
		local pvol
		for p = 1,#pvt do
			pvol= ExecInfo({ cmd = 'amixer get '.. pvt[p] })
			if not pvol:match('Unable') then break end
		end
		local so = { on = true, off = true }
		local s,p
		if pvol then
			s,p = pvol:match( "Mono: Playback.*%[(.-)%%%] %[.*%] %[(.-)%]" )
			if not s then
				s,p = pvol:match( "Front Left: Playback.*%[(.-)%%%] %[(.-)%]" )
			end
			if not so[p] then
				s,p = pvol:match( "Front Left: Playback.*%[(.-)%%%] %[.*%] %[(.-)%]" )
			end
		end
		return s, p or 0, 0
	end

	p.f = p.f or '12'


	-- local upwx = aa1

	if player == 'audacious' then

		audnow = {
			c_min="audtool --current-song-output-length",
			c_sec="audtool --current-song-output-length-seconds",
			c_alb="audtool --current-song-tuple-data album",
			c_art="audtool --current-song-tuple-data artist",
			c_ttl="audtool --current-song-tuple-data title",
			c_kbt="audtool --current-song-bitrate-kbps",
			c_khz="audtool --current-song-frequency-khz",
			c_chl="audtool --current-song-channels",
			t_min="audtool --current-song-length",
			t_sec="audtool --current-song-length-seconds",
			t_fnm="audtool --current-song-filename",
			p_ttl="audtool --playlist-length",
			p_pos="audtool --playlist-position",
			astat="audtool --playback-status",
			g_vol="audtool --get-volume",
		}

		local AudStatus = ExecInfo({ cmd = 'audtool --playback-status' })
		if AudStatus ~= 'stopped' then
			for c,d in pairs(audnow) do
				audnow[c] = ExecInfo({ cmd = d })
			end

			-- audnow.t_sec = 0
			audnow.c_chl = tonum(audnow.c_chl)
			audnow.p_ttl = tonum(audnow.p_ttl)
			audnow.t_sec = tonum(audnow.t_sec)

			if audnow.p_ttl == 1 then
				audnow.aud_tt = audnow.t_sec
			end

			if not audnow.g_vol or audnow.g_vol == '0' then audnow.g_volmain = 'Mute'
			elseif audnow.g_vol then audnow.g_volmain = audnow.g_vol end
			audnow.progress = (audnow.c_sec/audnow.t_sec)*100
			if time_to_go == 1 then
				audnow.c_sec = audnow.t_sec - audnow.c_sec
			end
			audnow.c_min=sprintf("%02d:%02d:%02d",(audnow.c_sec/3600),((audnow.c_sec/60)%60),(audnow.c_sec%60))
			audnow.t_min=sprintf("%02d:%02d:%02d",(audnow.t_sec/3600),((audnow.t_sec/60)%60),(audnow.t_sec%60))
			-- local att = audnow.aud_tt
			-- audnow.etime=sprintf("%02d:%02d:%02d",(att/3600),((att/60)%60),(att%60))
			audnow.etime=nil
		else
			audnow.t_fnm = nil
		end
	elseif player == 'vlc' then
		local JSON = require ("JSON")
		local vlcstats=tconcat({'wget --user= --password=',p.g,' -q http://127.0.0.1:8080/requests/status.json -O -'})
		local vlcr = ExecInfo({ cmd = vlcstats })
		if vlcr then
			vlcr = vlcr:gsub('Stream 1','Stream_1')
			vlcr = vlcr:gsub('Stream 0','Stream_0')
			local vlcp = JSON:decode(vlcr)
			if vlcp then
				audnow.astat=vlcp.state     --playing or paused
				if time_to_go == 1 then
					vlcp.time = vlcp.length - vlcp.time
				end
				audnow.c_min=sprintf("%02d:%02d:%02d",(vlcp.time/3600),
								((vlcp.time/60)%60),(vlcp.time%60)) --current track time elapsed
				audnow.progress = sprintf("%02d",vlcp.position*100) -- progress bas %
				audnow.g_vol = sprintf("%02.0f",vlcp.volume/2.56)     -- volume
				if vlcp.information then
					audnow.t_fnm=vlcp.information.category.meta.filename or '' -- filename
					audnow.c_alb=vlcp.information.category.meta.album or ''
					audnow.c_art=vlcp.information.category.meta.artist or ''
					if vlcp.information.category.meta.title then
						audnow.c_ttl=vlcp.information.category.meta.title
					else
						audnow.c_ttl=vlcp.information.category.meta.filename
					end
					audnow.t_min=sprintf("%02d:%02d:%02d",(vlcp.length/3600),
							((vlcp.length/60)%60),(vlcp.length%60)) --current track ttl time

					if vlcp.information.category.Stream_0 and
						vlcp.information.category.Stream_0.Type == 'Audio' then
						audnow.c_kbt = vlcp.information.category.Stream_0.Bitrate or 0
						audnow.c_khz = vlcp.information.category.Stream_0.Sample_rate:match("(%d+)")
						audnow.c_chl = vlcp.information.category.Stream_0.Channels
					elseif vlcp.information.category.Stream_1 and
						vlcp.information.category.Stream_1.Type == 'Audio' then
						audnow.c_kbt = vlcp.information.category.Stream_1.Bitrate or 0
						audnow.c_khz = vlcp.information.category.Stream_1.Sample_rate:match("(%d+)")
						audnow.c_chl = vlcp.information.category.Stream_1.Channels
					end

					if vlcp.information.category.Stream_0 and
						vlcp.information.category.Stream_0.Type == 'Video' then
						audnow.v_cod = vlcp.information.category.Stream_0.Codec
						audnow.v_asp = vlcp.information.category.Stream_0.Resolution
						audnow.v_vbr = vlcp.information.category.Stream_0.Frame_rate
						audnow.v_vbr = sprintf("%02.0f",audnow.v_vbr)
					elseif vlcp.information.category.Stream_1 and
							vlcp.information.category.Stream_1.Type == 'Video' then
						audnow.v_cod = vlcp.information.category.Stream_1.Codec
						audnow.v_asp = vlcp.information.category.Stream_1.Resolution
						audnow.v_vbr = vlcp.information.category.Stream_1.Frame_rate
						audnow.v_vbr = sprintf("%02.0f",audnow.v_vbr)
					end
					-- print(audnow.v_asp,audnow.v_vbr)
					if not audnow.c_kbt then audnow.c_kbt = audnow.c_kbt:match("(%d+)") end
					audnow.c_khz = sprintf("%02d",(audnow.c_khz/1000))

					if not audnow.p_pos then audnow.p_pos = 1 end
					if not audnow.p_ttl then audnow.p_ttl = 1 end
				end
			end
			local vlcstats=tconcat({'wget --user= --password=',p.g,' -q http://127.0.0.1:8080/requests/playlist.json -O -'})
			local vlcr = ExecInfo({ cmd = vlcstats })
			if vlcr then
				local vlcp = JSON:decode(vlcr)
				local tpt = 0
				if vlcp then
					for d = 1, #vlcp.children[1].children do
						tpt = tpt + vlcp.children[1].children[d].duration
						if vlcp.children[1].children[d].current then
							audnow.p_pos = d
						end
					end
					audnow.p_ttl=#vlcp.children[1].children
					audnow.etime = sprintf("%02d:%02d:%02d",(tpt/3600), ((tpt/60)%60),(tpt%60))
				end
			end
		end
	elseif player == 'mplayer' and DirExists('/tmp/wxmptmp/') then
		-- local m3utmp = '/tmp/wxmptmp/tmpflist.m3u'
		-- local RndmIdx   = '/tmp/wxmptmp/random'
		-- local mpfifo = '/tmp/wxmptmp/mpfifo'

		audnow.astat = ExecInfo({ rfile = '/tmp/wxmptmp/ANS_pause' })
		if not audnow.astat or audnow.astat == '' then
			audnow.astat = 'yes'
		end

		audnow.c_sec = ExecInfo({ rfile = '/tmp/wxmptmp/ANS_time_pos' })
		audnow.c_sec = tonum(audnow.c_sec) or 0

		if not audnow.t_fnm or audnow.t_fnm:match('echo') then
			audnow.t_fnm = 'Buffering...'
		end

		if audnow.t_fnm then
			local goto_trk

			local curr_trk, prev_trk, next_trk
			local trackno = ExecInfo({ rfile = '/tmp/wxmptmp/trackno' })
			trackno = tonum(trackno) or 1

			ct_info = ExecInfo({ rfile = '/tmp/wxmptmp/ct_info' })
			if ct_info then
				local ctin   = {}
				ctin         = wxsplit(ct_info,':::')
				audnow.p_pos = trackno
				audnow.t_fnm = ctin[1]        or 'Buffering...'
				audnow.c_ttl = ctin[2]        or 'Buffering...'
				audnow.c_min = tonum(ctin[3])
				audnow.c_kbt = tonum(ctin[4])
				audnow.c_khz = ctin[5]
				audnow.c_chl = tonum(ctin[6])
				tpt          = tonum(ctin[7])
				audnow.p_ttl = tonum(ctin[8])
			end
			-- print(tpt)

			tpt = tpt or 0
			local tptHours = tpt / 3600
			if tptHours > 99 then tptHours = 99 end
			audnow.etime = sprintf("%02d:%02d:%02d",tptHours,((tpt/60)%60),(tpt%60))

			local lloop = ExecInfo({ rfile = '/tmp/wxmptmp/loop' })
			if lloop then
				if lloop:match('loop') then
					loop_times = tonum(lloop:match("(%-?%d+)"))
				end
				if loop_times == 0 then
					loop_times = 99
				end
			else
				loop_times = nil
			end

			local shuffling,ctrk
			if FileExists('/tmp/wxmptmp/shuffle') then shuffling = true end

			if loop_times then
				shfl_loop_label = tconcat({'Loop ',lr,'/',loop_times})
				local lcnt = ExecInfo({ rfile = '/tmp/wxmptmp/lcnt' })
				if lcnt then lr = tonum(lcnt:match("(%d+)")) end
			elseif shuffling == true then
				shfl_loop_label = ' Shfl'
			else
				shfl_loop_label = ''
			end

			audnow.progress = (audnow.c_sec/audnow.c_min)*100

			if time_to_go == 1 then
				audnow.c_sec = audnow.c_min - audnow.c_sec
			end
			audnow.t_min = sprintf("%02d:%02d:%02d",(audnow.c_min/3600), ((audnow.c_min/60)%60),(audnow.c_min%60));
			audnow.c_min = sprintf("%02d:%02d:%02d",(audnow.c_sec/3600), ((audnow.c_sec/60)%60),(audnow.c_sec%60));

			audnow.etime = audnow.etime or audnow.t_min
			audnow.p_ttl = audnow.p_ttl or 1
			audnow.c_kbt = sprintf("%02d",(audnow.c_kbt/1000))
			audnow.c_khz = sprintf("%02d",(audnow.c_khz/1000))
		end
	end
		-- print(audnow.p_pos)
	if not p.d and audnow.t_fnm then
		local aud_ch
		audnow.c_chl = audnow.c_chl or 0
		local chnl = {Stereo='St',Mono='Mo'}
		if type(audnow.c_chl) == 'string' then
			aud_ch = chnl[audnow.c_chl]
		elseif type(audnow.c_chl) ~= 'string' and audnow.c_chl >= 2 then
			aud_ch = 'St'
		else
			aud_ch = 'Mo'
		end

		local playstate = {yes='paused',paused='paused',no='playing',playing='playing'}
		audnow.pause = playstate[audnow.astat]
		if audnow.p_pos then
			local getlastnum=tonum(string.sub(audnow.p_pos,-1))
		end
		-- audnow.c_art audnow.c_alb audnow.c_ttl
		-- print('c_art'..audnow.c_art..'c_art')
		if audnow.c_art and audnow.c_art ~= '' then
			audnow.c_art = tconcat({audnow.c_art,' / '})
		else audnow.c_art = '' end
		if audnow.c_alb and audnow.c_alb ~= '' then
			audnow.c_alb = tconcat({audnow.c_alb,' / '})
		else audnow.c_alb = '' end

		local traxtxt
		-- print(audnow.p_ttl,audnow.p_pos)
		if audnow.v_asp or audnow.v_vbr then
			aud_ch = tconcat({audnow.v_asp,':',audnow.v_vbr,'/',aud_ch})
			if audnow.p_ttl and audnow.p_ttl > 1 then
				traxtxt = tconcat({firstToUpper(audnow.pause),':',audnow.p_pos, '/',audnow.p_ttl})
			else
				traxtxt = tconcat({firstToUpper(audnow.pause),': 1'})
			end
		else
			if audnow.p_ttl and audnow.p_ttl > 1 then
				traxtxt = tconcat({firstToUpper(audnow.pause),': ',audnow.p_pos, '/',audnow.p_ttl,' tracks'})
			else
				traxtxt = tconcat({firstToUpper(audnow.pause),': Single track'})
			end
		end

		if time_to_go == 1 then
			audnow.c_min = '-'..audnow.c_min
		end

		if not audnow.c_ttl or audnow.c_ttl == '' then
			audnow.c_ttl = audnow.t_fnm
		end

		local titletxt = tconcat({ audnow.c_art, audnow.c_alb, audnow.c_ttl,'  :::'})
		titletxt = strip_ext_codes(titletxt):gsub("%s+", " ")
		local infotxt1
		if not audnow.etime then
			infotxt1 = tconcat({
				audnow.c_min,'/',audnow.t_min,' ',shfl_loop_label,
			})
		else
			infotxt1 = tconcat({
				audnow.c_min,'/',audnow.t_min,'/',audnow.etime,' ',shfl_loop_label,
			})
		end
		local infotxt2 = tconcat({aud_ch,'/',audnow.c_khz,'kHz/',audnow.c_kbt,'kbps'})

		audnow.g_volmain, audnow.mute = getVolume()
		if audnow.mute == 'off' then
			audnow.g_volmain = 'Mute'
		end
		if player == 'vlc' then
			audnow.g_vol = tconcat({'Vol:',audnow.g_vol,'%/',audnow.g_volmain,'%'})
		else
			if audnow.g_volmain and audnow.g_volmain ~= 'Mute' then
				audnow.g_vol = tconcat({'Vol:',audnow.g_volmain,'%'})
			else
				audnow.g_vol = tconcat({'Vol:',audnow.g_volmain})
			end
		end
		local voltxt = audnow.g_vol

		-- bar colour
		local ecolour  = p.e or tconcat({Lime,':1'})
		ecolour        = wxsplit(ecolour,":")
		local aud_bar_style={
			f='',
			a=audnow.progress or 0,
			lwx=p.lwx+3,
			lwy=p.lwy+2,
			w=p.b or conky_window.width-10,
			s=p.k or 5,
			c=ecolour,
			e=ecolour,
			d={{ecolour[1],ecolour[1],ecolour[1]}},
		}
		bargraph_styles(aud_bar_style)

		-- text colour
		local ccolour = p.c
		ccolour = wxsplit(ccolour,":")
		cairo_set_source_rgba(cr, to_rgba(ccolour))
		cairo_save(cr)
		if not p.f:match(':') then set_font(tconcat({'normal:',p.f})) else set_font(p.f) end

		local extents=cairo_text_extents_t:create()
		cairo_text_extents(cr,titletxt,extents)
		p.l = p.l or (conky_window.width/(extents.width/string.len(titletxt)))-2.5

		local scroller_data={
			l		= p.l		or 36,		-- scroll text length
			s		= p.s		or 5,		-- scroll text step
			w		= p.w		or "B",		-- direction of scroll
			updates	= p.updates,				-- internal update count
			lwx		= p.lwx		or 50,		-- x coordinate
			lwy		= p.lwy-(extents.height*0.8) or 250,		-- y coordinate
			d		= titletxt,             -- text to scroll
			c		= p.c, 			        -- scroll text colour
			a		= 'l',		            -- text align
			i		= p.i		or 10,		-- vertical scroll jump
			f		= p.f       or 12,		-- font size:name:style etc
			r		= p.r		or 0,		-- range of vertical scroll
			o		= p.o		or "NA",	-- file path/name w scroll text
		}
		do_scroller(scroller_data)
		-- print(scroller_data.lwy)

		make_txt({ text=infotxt1, px=p.lwx, py=p.lwy+extents.height+3, align='l'})
		make_txt({ text=voltxt, px=conky_window.width-5, py=p.lwy+extents.height+3, align='r'})
		make_txt({ text=traxtxt, px=p.lwx, py=p.lwy+(extents.height*2.2)+3, align='l'})
		make_txt({ text=infotxt2,  px=conky_window.width-5, py=p.lwy+(extents.height*2.2)+3, align='r'})
	end
end-------- -- }}}

local function do_vumeter(vala)		--- {{{

	------ derived and inspired by humidity vertical display
	------ thanks to the original contributor ???????
	---- vumeter by paramvir 2014
	-- show UV humidity and Visibility - to make it generic
	-- u-value, l-label,x,y,vsfactor,s,m and e colour
	--- o value, d-value, x,y,u for unit
	-- vala.lwx = 180
	-- vala.lwy = 100
	---- for UV
	-- vala.l = "UV"
	-- vala.o = "U"
	-- vala.d=vala.uvi
	-- vala.u = "F"
	-- vala.o = "V"
	-- vala.d=vala.vis
	-- vala.d = "7.5"
	-- vala.o = "H"
	-- vala.d=vala.hum
	-- vala.o = "M"
	-- vala.d=vala.mil
	-- print(vala.mil)
	-- vala.d = "75"
	-- vala.d = "NA"
	-- vala.o = string.upper(vala.o)
	local no_data="vumeter - No data input"
	local valid_opts="vumeter - Valid -o options-M,H,U or V"

	local x 			= vala.lwx+4.5		or 0
	local y 			= vala.lwy			or 0
	local hdata 		= vala.d			or print(no_data)
	local maxuv 		= vala.x			or nil
	local opth 			= vala.o			or print(valid_opts)
	local hide_numbers	= vala.i			or 0
	local vhstyle		= vala.v			or "v"
	local runit			= vala.u
	local moonstt		= vala.m			or ""
	local ptrc			= vala.e			or nil --Lime..":1"
	local numc			= vala.f			or nil --DarkGold..":1"
	local txtc			= vala.g			or nil --Cyan..":1"
	local label			= vala.l			or nil

	if ptrc then ptrc = wxsplit(ptrc,":") end
	if numc then numc = wxsplit(numc,":") end
	if txtc then txtc = wxsplit(txtc,":") end
	-- hdata=100 -g 0x0000FF:1 -e 0xff0000:1 -f 0x00f0FF:0.8

	local sizeval={}
	if vala.s then
		-- if vala.s:match(":") then
			sizeval = wxsplit(vala.s,":")
		-- else
			-- sizeval[1] = vala.s
		-- end
	else
		if sizeval[1]=="" then sizeval[1]=150 end
		if sizeval[2]=="" then sizeval[2]=30 end
	end

	local maxscale		= tonum(sizeval[1]) 			or 150
	local maxht			= tonum(sizeval[2])			or 30

	vhstyle = string.upper(vhstyle)
	opth = string.upper(opth)

	local hval1 = nil
	local sep = nil
	local sep2 = nil
	local sval1 = nil
	local cstop = {}
	local scolour = {}
	local mcolour = {}
	local ecolour = {}
	local hunit= nil
	local labeln = nil

	if opth == "U" then
		sep = ":"
		if maxuv then sep2=tconcat({"-","Max:",maxuv}) else sep2="" end
		label = label or "UV"
		-- txtc = txtc or {0x0000FF,1}
		txtc = txtc or {Yellow,1}
		ptrc = ptrc or {0x000fff,1}
		numc = numc or {0x00f0FF,0.8}
		cstop = {0,0.7,1}
		scolour = {0xFF0000,0.9}
		mcolour = {0xCD950C,0.5}
		ecolour = {0x00FF00,0.3}
		hunit=" "
	elseif opth == "V" then
		sep = " ";sep2=" - "
		if maxscale <=100 then labeln="Vis" else labeln="Visibility" end
		label = label or labeln
		txtc = txtc or {0x0000FF,1}
		ptrc = ptrc or {0xff00ff,1}
		numc = numc or {0x00f0FF,0.7}
		cstop = {0,0.5,1}
		scolour = {0xB9B9B9,0}
		mcolour = {0xB9B9B9,0.2}
		ecolour = {0xB9B9B9,1}
		if runit=="F" then hunit=" mi" else hunit=" km" end
	elseif opth == "H" then
		sep = "%%";
		if hide_numbers~=1 then sep2="-x10-" else sep2="-" end
		if maxscale <=100 then labeln="RH" else labeln="R Humidity" end
		label = label or labeln
		txtc = txtc or {Cyan,1}
		ptrc = ptrc or {0xff00ff,1}
		numc = numc or {Lime,0.7}
		cstop = {0,0.5,1}
		scolour = {0x4169E1,1}
		mcolour = {0x4169E1,0.5}
		ecolour = {0x4169E1,0}
		hunit='%'
	elseif opth == "M" then
		sep = "%%";
		if hide_numbers~=1 and maxscale>=100 then sep2=tconcat({"-",moonstt,"-x10"})
		else sep2="-" end
		label = label or "Moon"
		-- -g 0xBCEE68:1
		txtc = txtc or {Cyan,1}
		ptrc = ptrc or {0xff00ff,1}
		numc = numc or {Lime,0.7}
		cstop = {0,0.3,1}
		scolour = {0xFFFFff,0.5}
		mcolour = {0xb0b0b0,0.4}
		ecolour = {0x000000,0.3}
		hunit='%'
	end
		-- print(label1)
	if hdata ~= "NA" then
		local vsval = wxsplit(hdata,sep)
		if vsval[1] then hval1= tonum(vsval[1]) else hval1=0 end
		-- if vsval[2] then sval1=sep2..hdata
		-- end
		-- if opth == "U" then sval1= sep2..vala.d else sval1 = sep2..hval1..hunit end
		if opth == "U" then
			sval1= tconcat({"-",vala.d,sep2})
		else
			sval1 = tconcat({"-",hval1,hunit,sep2})
		end
	else
		hval1=0; sval1=" - N/A"
	end
	-- print(scolour)
	local wmax=(maxscale-14)
	if opth == "H" or opth == "M" then hval2=(hval1/10)
	else hval2=hval1 end
	hval=((wmax/10) * hval2)
	-- hval=(vala.v * hval1)
	if hval >= wmax then hval = wmax end
	if vhstyle == "H" then
		rh=maxht; rw=(maxscale)
		pat = cairo_pattern_create_linear (x+rw,0,x,0);
		hh=5; hw1=(rh-11); hw2=hw1+10; sx=x+5
		if hval==nil then hval=0 end
		tx,ty=(sx+hval+hh),y+hw1
		ix,iy=(sx+hval),y+hw2
		bx,by=(sx+hval-hh),y+hw1
	elseif vhstyle == "V" then
		yt=y-1; rh=maxscale; rw=maxht
		pat = cairo_pattern_create_linear (0,yt,0,yt+rh);
		hh=5; hw1=(rw-11); hw2=hw1+10; sy=y+maxscale-5
		if hval==nil then hval=0 end
		tx,ty=x+hw1,(sy)-(hval+hh)
		ix,iy=x+hw2,(sy)-hval
		bx,by=x+hw1,(sy)-(hval-hh)
	end
	cairo_pattern_add_color_stop_rgba (pat, cstop[1], to_rgba(scolour))
	-- if opth ~= "M" then
	cairo_pattern_add_color_stop_rgba (pat, cstop[2], to_rgba(mcolour))
	-- end
	cairo_pattern_add_color_stop_rgba (pat, cstop[3], to_rgba(ecolour))
	cairo_rectangle (cr,x,y,rw, rh);
	cairo_set_source (cr, pat);
	cairo_fill (cr);
	cairo_pattern_destroy (pat);
	----------
	----------
	--- set the pointer
	cairo_set_source_rgba (cr, to_rgba(ptrc)) -- pointer colour
	cairo_move_to (cr,tx,ty)
	cairo_line_to (cr,ix,iy)
	cairo_line_to (cr,bx,by)
	cairo_line_to (cr,tx,ty)
	cairo_fill (cr)

	cairo_save(cr)
	set_font("Mono:11")

	-- notches on right of slider
	-- 121@in.airtel.com, nodal.ncr@in.airtel.com - 16349566
	-- 2099, 80gb
	-- 2849 - 3200 175 8 mbps -14843491 service request - tag 359398014
	cairo_set_source_rgba (cr,to_rgba(numc))  --- marker and number colour
	local inc1
	for i=1,11 do
		local lwid=-3
		local inc1=nil
		cairo_set_line_width (cr,1)
		if vhstyle == "H" then
			imarks = (sx+wmax)-((i-1)*(wmax/10))
			cairo_move_to (cr,imarks,y+rh)
			cairo_rel_line_to (cr,0,lwid)
			if maxscale <= 100 then
				if i%2==0  then inc1=(11-i)
				else inc1=" " end
			else inc1=(11-i) end
			cairo_save(cr)
			if hide_numbers ~= 1 then
				make_txt({ text=inc1, px=imarks-1, py=y+hw2-3 })
			else
				-- cairo_set_source_rgba (cr,to_rgba(numc))
				cairo_stroke(cr)
			end
		elseif vhstyle == "V" then
			imarks = (sy)-((i-1)*(wmax/10))
			cairo_move_to (cr,x+rw,imarks)
			cairo_rel_line_to (cr,lwid,0)
			if maxscale <= 100 then
				if i%2==0  then inc1=(i-1)
				else inc1=""
				end
			else inc1=(i-1)	end
			cairo_save(cr)
			if hide_numbers ~= 1 then
				make_txt({ text=inc1, px=x+rw-10, py=imarks+3 })
			else
				-- cairo_set_source_rgba (cr,to_rgba(numc))
				cairo_stroke(cr)
			end
		end
	end
	-- local outtext = nil
	local label = tconcat({label,sval1})

	cairo_save(cr)
	set_font("Mono:12")
	cairo_set_source_rgba (cr,to_rgba(txtc)) -- label colour
	cairo_save(cr)
	if vhstyle == "H" then
		cairo_move_to (cr,x+3,y+12)
	elseif vhstyle == "V" then
		cairo_move_to (cr,x+12,sy)
		cairo_rotate (cr,TORADIANS*(-90))
		-- cairo_rotate (cr,TORADIANS*(90))
	end
	cairo_show_text (cr,label)
	cairo_stroke (cr)

end --end vumeter		}}}


local function do_clock(vala)
--[[
fancyclock.lua - lua script for the mechanical clock
Sunday, 20 October 2013 13:55 - original source from written by easysid
This program is free software. You are free, infact encouraged, to modify it as you deem fit, and freely distribute.

:: This widget has been heavily modified to comply with conkywx
2015 - Paramvir
--]]

	local function draw_sweep(t)

		cairo_save(cr)
		cairo_set_source_rgba(cr, to_rgba(t.scol))
		-- cairo_set_line_width(cr, t.ds.line_width*1.5)
		cairo_set_line_width(cr, t.arc_thickness)
		cairo_arc(cr, t.x, t.y, t.R, t.start_angle * TORADIANS, t.end_angle * TORADIANS)
		cairo_stroke(cr)
		cairo_restore(cr)

	end

	local function draw_clock_hands(t)

		local hsecs, hours, apx, apy

		local m_scale = t.m_scale or 0.5
		local h_scale = t.h_scale or 0.5
		local ap_scale = t.ds.csize*.20 or 0.25

		-- show ampm at the center if size less than 150 pixels - 0.5
		apx      = t.ds.x
		if t.ds.csize < 0.419 then
			apy      = t.ds.y
			ap_scale = t.ds.csize*.41 or 0.25
		else
			apy      = t.ds.y - (t.ds.y*0.35)
		end
		-- print(t.ds.csize)

		-- local apy      = t.y - (t.y*ap_scale)

		local secs = tonum(os.date("%S"))
		local minutes = tonum(os.date("%M"))
		--calculate the seconds for each
		local msecs = minutes*60 + secs
		local start_sweep
		if  not t.ds.thc then
			-- 12 hour clock
			hours = tonum(os.date("%I"))
			-- hours = 11.5
			hsecs = (hours*3600 + msecs)
			start_sweep = (0-90)
		else
			-- 24 hour clock
			hours = tonum(os.date("%H"))
			if t.ds.thc == 2 then
				hsecs = ((hours+12)*3600 + msecs)/2
				start_sweep = (0+90)
			else
				hsecs = (hours*3600 + msecs)/2
				start_sweep = (0-90)
			end
		end
		-- local m_theta = msecs*2*PI/3600 - PI/2
		local m_theta = TORADIANS*((msecs*0.1)-90)
		-- local h_theta = hsecs*2*PI/43200 - PI/2
		local h_theta = TORADIANS*((hsecs/120)-90)

		-- Show am/pm  #########################################
		if not t.ds.thc and t.show_ap ~= 0 then
			local ap_file = 'ampm.png'
			local ap_hsecs = (tonum(os.date("%H"))*3600 + msecs)
		-- show ampm image
			put_image({
				-- x		= t.ds.x,
				-- y		= t.ds.y,
				x      = apx,
				y      = apy,
				file   = ap_file,
				scale  = ap_scale,
				ip     = t.ds.ip  })
			cairo_save(cr)
			choose_indicator({
				-- px		= t.ds.x,
				-- py		= t.ds.y,
				px		= apx,
				py		= apy,
				startval= 0-90,
				scale	= ap_hsecs*(360/86400),
				rout1	= 140*ap_scale,
				ch_indi = 8,
				cthick  = t.ds.line_width,
				csize   = t.ds.csize,
				-- chands  = 1,
				icolour = {0xff00ff,1}, })
				-- icolour = {0xffffff,1}, })
			-- choose_indicator({
			-- 	px		= t.ds.x,
			-- 	py		= t.ds.y,
			-- 	startval= 0-90,
			-- 	scale	= ap_hsecs*(360/86400),
			-- 	rout1	= m_scale*200,
			-- 	ch_indi = 2,
			-- 	cthick  = t.ds.line_width,
			-- 	csize   = t.ds.csize,
			-- 	chands  = 1,
			-- 	icolour = {0x00ffff,1}, })
			-- 	-- icolour = {0x00ffff,1}, })
		end

		-- print(t.show_dd)
		if t.show_dd and t.show_dd ~= 0 then
			-- draw weekdays  #########################################
			local R = t.length, xfact
			local r = 5*t.ds.csize -- the radius of the small circle of seconds hand

			if t.ds.hm_arrows == 10 then
				-- xfact = R*1.8
				xfact = R*2.3
			else
				xfact = R*2.3
			end

			-- cairo_set_source_rgba(cr, to_rgba(t.arrow_colour))
			cairo_save(cr)
			if t.arrow_colour and t.ds.csize >= 0.419 then
				local wdays, mts
				if t.ds.csize < 0.45 then
					set_font("Mono:8:bold")
				elseif t.ds.csize < 0.8 then
					set_font("Mono:10:bold")
				else
					set_font("Mono:12:bold")
				end
				wdays={"S","M","T","W","T","F","S"}
				cairo_save(cr)
				cairo_set_source_rgba(cr, to_rgba({"0x666666",0.7}) )
				cairo_arc(cr, t.ds.x+xfact, t.ds.y, R*1.3, TORADIANS, 0)
				cairo_fill(cr)
				-- cairo_set_source_rgba(cr, to_rgba(t.arrow_colour))
				cairo_set_source_rgba(cr, to_rgba({Lime,1}))
				cairo_save(cr)
				for i=1,#wdays do
					make_scale_txt2({
						xval		= t.ds.x+xfact,
						yval		= t.ds.y,
						startscale	= 0,
						endscale	= 360,
						maxscale	= #wdays,
						trout		= R-1,
						text		= wdays[i],
						dotext      = 1,
						i			= i-1,	})
				end
				cairo_save(cr)
				local wd = tonum(os.date("%w"))
				choose_indicator({
					px		= t.ds.x+xfact,
					py		= t.ds.y,
					startval= 0,
					scale	= (360/7)*wd,
					rout1	= R,
					ch_indi = 6,
					-- chands  = 1,
					cthick  = t.ds.line_width,
					csize   = t.ds.csize,
					icolour = {0xffff00,1}, })

			-- draw months and date #########################################
				-- cairo_save(cr)
				cairo_restore(cr)
				if t.ds.csize < 0.8 then
					set_font("Mono:12:bold")
				else
					set_font("Mono:18:bold")
				end
				-- set_font("Mono:14:bold")
				local mt = os.date("%b")
				local dt = os.date("%d")
				-- mt="September"
				cairo_set_source_rgba(cr, to_rgba({"0x666666",0.7}) )
				cairo_arc(cr, t.ds.x-xfact, t.ds.y, R*1.3, TORADIANS, 0)
				cairo_fill(cr)
				-- cairo_save(cr)
				-- cairo_set_source_rgba(cr, to_rgba(t.arrow_colour))
				make_txt({ text=mt, px=t.ds.x-xfact, py=t.ds.y })
				make_txt({ text=dt, px=t.ds.x-xfact, py=t.ds.y+Global_Font_Size })
				cairo_save(cr)
			end
		end

		if t.ds.hm_arrows > 6 and t.ds.style ~= 3 then
		-- draw the clock arrows hours and minutes #########################################
			local h_hand = tconcat({'hr',t.ds.hm_arrows,'.png'})
			-- local h_hand = 'hr1.png'
			-- local h_hand = 'mn0.png'
			local m_hand = tconcat({'mn',t.ds.hm_arrows,'.png'})
			-- local m_hand = 'mn9.png'
			-- local m_hand = 'mn0.png'
			-- local m_hand = 'mn1.png'
			put_image({
				x      = t.ds.x,
				y      = t.ds.y,
				file   = m_hand,
				scale  = m_scale,
				theta  = m_theta,
				rotate = true,
				dial_colour  =  t.arrow_colour,
				ip     = t.ds.ip,  })
			put_image({
				x      = t.ds.x,
				y      = t.ds.y,
				file   = h_hand,
				scale  = h_scale,
				theta  = h_theta,
				rotate = true,
				dial_colour  =  t.arrow_colour,
				ip     = t.ds.ip,  })
		end
		-- local hfactor = 85
		-- local mfactor = 100
		-- local mfactor = 123.6
		-- local hfactor = 63
		-- local mfactor = 66
		local hfactor = 144
		local mfactor = 154
		-- print(m_scale,h_scale,t.ds.csize,t.ds.csize*mfactor,m_scale*123.6)

		-- 12 hour ring
		-- hour sweep
		if  t.ds.style == 3 or
			t.ds.style == 4 then
			cairo_save(cr)
			local start_angle = start_sweep
			local end_angle   = (((hsecs-(12*3600))/120) - 90)
			draw_sweep({
				x = t.ds.x,
				y = t.ds.y,
				arc_thickness = t.ds.arc_thickness,
				scol = t.arrow_colour,
				-- R = t.ds.csize*hfactor,
				R = h_scale*hfactor,
				start_angle = start_angle,
				end_angle   = end_angle,
			})
			if t.ds.style == 4 then chands = 1 end
		end
		if  t.ds.style ~= 3 and t.ds.hm_arrows < 7 then
			cairo_save(cr)
			choose_indicator({
				px		= t.ds.x,
				py		= t.ds.y,
				startval= 0+90,
				-- startval= 0,
				scale	= ((hsecs/120)-90),
				-- rout1	= (R/m_scale)*3.5,
				-- rout1	= t.ds.csize*hfactor,
				rout1	= h_scale*hfactor,
				ch_indi = t.ds.hm_arrows,
				-- cthick  = t.line_width,
				cthick  = t.ds.arc_thickness,
				csize   = t.ds.csize,
				chands  = 1,
				icolour = t.arrow_colour, })
		end

		if  t.ds.style == 3 or
			t.ds.style == 4 then
			cairo_save(cr)
			-- min sweep
			local start_angle = (0-90)
			local end_angle   = ((msecs*0.1)-90)
			draw_sweep({
				x = t.ds.x,
				y = t.ds.y,
				arc_thickness = t.ds.arc_thickness,
				scol = t.arrow_colour,
				-- R = t.ds.csize*mfactor,
				R = m_scale*mfactor,
				start_angle = start_angle,
				end_angle   = end_angle,
			})
			if t.ds.style == 4 then chands = 1 end
		end
		if  t.ds.style ~= 3 and t.ds.hm_arrows < 7 then
			cairo_save(cr)
			choose_indicator({
				px		= t.ds.x,
				py		= t.ds.y,
				startval= 0+90,
				scale	= ((msecs*0.1)-90),
				-- rout1	= (R/h_scale)*3.5,
				-- rout1	= t.ds.csize*mfactor,
				rout1	= m_scale*mfactor,
				ch_indi = t.ds.hm_arrows,
				-- cthick  = t.line_width,
				cthick  = t.ds.arc_thickness,
				csize   = t.ds.csize,
				chands  = 1,
				icolour = t.arrow_colour, })
		end

	end 	-- end of draw_clock_hands


	local function draw_seconds(t)

		local R = t.length
		local r = 5*t.ds.csize -- the radius of the small circle of seconds hand

		local secs = os.date("%S")
		local start_angle = (0 - 90)
		local end_angle   = ((secs*6) - 90)

		cairo_set_source_rgba (cr, to_rgba(t.ds.scol))

		if not t.sweep_colour then
			sweep_file = 'sweep2.png'
		else
			sweep_file = 'sweep3.png'
		end

		if t.ds.style == 1 then
			chands = nil
			cairo_set_source_rgba(cr, to_rgba({Grey81,0.7}) )
			cairo_arc(cr, t.ds.x, t.ds.y, R*1.3, TORADIANS, 0)
			cairo_fill(cr)
			cairo_set_source_rgba (cr, to_rgba(t.ds.rcol))
			cairo_save(cr)
			for i=1,60 do
				if (i%5==0) then
					rini=R+(5*t.ds.csize)
					cairo_set_line_width (cr,(1.5*t.ds.csize))
				else
					rini=R+(3*t.ds.csize)
					cairo_set_line_width (cr,(0.5*t.ds.csize))
				end
				cairo_save(cr)
				make_scale_txt2({
					startscale	= 0,
					endscale	= 360,
					maxscale	= 60,
					rout		= R,
					rin			= rini,
					xval		= t.ds.x,
					yval		= t.ds.y,
					i			= i		})
			end
			cairo_stroke(cr)
			if t.ds.csize < 0.8 then
				set_font("Mono:8:bold")
			else
				set_font("Mono:11:bold")
			end
			local degs1={"0","20","40"}
			for i=1,#degs1 do
				make_scale_txt2({
					startscale	= 0,
					endscale	= 360,
					maxscale	= #degs1,
					trout		= R-(r*1.85),
					text		= degs1[i],
					dotext      = 1,
					xval		= t.ds.x,
					yval		= t.ds.y,
					i			= i-1	})
			end
			cairo_save(cr)
		elseif t.ds.style == 2 then
		-- draw seconds as a dot
			local jx,jy = get_points(0, secs*6 , 0 ,R)
			cairo_arc(cr, t.ds.x+jx, t.ds.y+jy, t.ds.line_width*2, TORADIANS, 0)
			cairo_fill(cr)
		elseif  t.ds.style == 3 or
				t.ds.style == 4 then
			draw_sweep({
				x = t.ds.x,
				y = t.ds.y,
				arc_thickness = t.ds.arc_thickness,
				scol = t.ds.scol,
				R = R,
				start_angle = start_angle,
				end_angle   = end_angle,
			})
			if t.ds.style == 4 then chands=1 end
		elseif t.ds.style == 5 then
			chands=1
		elseif t.ds.style == 8 then
			chands=1
			t.ch_indi=8
		elseif t.ds.style == 6 then
			put_image({
				x      = t.ds.x,
				y      = t.ds.y,
				file   = sweep_file,
				scale  = R/148,
				theta  = end_angle * TORADIANS,
				dial_colour = t.sweep_colour,
				rotate = true,
				ip     = t.ds.ip  })
			chands=1
		elseif t.ds.style == 7 then
			put_image({
				x      = t.ds.x,
				y      = t.ds.y,
				file   = sweep_file,
				scale  = R/148,
				theta  = end_angle * TORADIANS,
				dial_colour = t.sweep_colour,
				rotate = true,
				ip     = t.ds.ip  })
		end
		cairo_save(cr)

		if  t.ds.style ~= 2 and
			t.ds.style ~= 3 and
			t.ds.style ~= 7 then
		-- if t.ds.style ~= 3 then
			choose_indicator({
				px		= t.ds.x,
				py		= t.ds.y,
				startval= 0,
				scale	= secs*6,
				rout1	= R,
				ch_indi = t.ch_indi or 6,
				-- cthick  = t.line_width*1.5,
				cthick  = t.ds.line_width,
				csize   = t.ds.csize,
				chands  = chands,
				-- icolour = {0xff0000,1}, })
				icolour = t.ds.scol, })
		end


	end 	-- end of draw_seconds


	local function run_gear(t)

		local file = t.file or 'gear1.png'
		local max = t.max or MAX
		local dir = t.dir or 1
		local scale = t.scale or 1
		local tick = t.tick or false
		if tick then
			value = t.arg or tonum(conky_parse("${updates}"))
		else
			value = tonum(conky_parse("${updates}")) % max
		end
		-- local theta = dir*value*2*PI/max - PI/2
		local theta = dir*value*6/max - 90
		put_image({
			x      = t.x,
			y      = t.y,
			file   = file,
			theta  = theta,
			scale  = scale,
			rotate = true,
			ip     = t.ip  })

	end 	-- end of run_gear



	local function draw_clock_face(t)

		cairo_save(cr)

		local R = t.length*80
		local r = 5*t.ds.csize -- the radius of the small circle of seconds hand
		local hour_factor, localhf, roman, marks_main, marks_sec, radius_marks, radius_num
		local rini, sweep_factor, show_num

		-- setup Face gradient
		local grad_colour
		-- t.bcolour = Red..":1"
		if t.bcolour:match("::") then  -- check for gradient 3 colours
			grad_colour = wxsplit(t.bcolour,"::")
			grad_colour[1] = wxsplit(grad_colour[1],":")
			grad_colour[2] = wxsplit(grad_colour[2],":")
			grad_colour[3] = wxsplit(grad_colour[3],":")
		else
			-- print(t.bcolour)
			-- local bcolour1 = {Red..":1"}
			local bcolour1 = wxsplit(t.bcolour,":")
			cairo_set_source_rgba(cr, to_rgba(bcolour1))
			cairo_arc(cr, t.ds.x, t.ds.y, 149*t.ds.csize, TORADIANS,0)
			cairo_fill(cr);
			cairo_save(cr)
		end

		local cface
		if t.file >= 9 then
			put_image({
				x          =  t.ds.x,
				y          =  t.ds.y,
				file       =  tconcat({'face',t.file,'.png'}),
				scale      =  t.ds.csize,
				ip         =  t.ds.ip
			})
		else
			cface = t.file
			if grad_colour then
				r1 = cairo_pattern_create_radial(t.ds.x, t.ds.y, 75 * t.ds.csize, t.ds.x, t.ds.y, 150 * t.ds.csize);
				cairo_pattern_add_color_stop_rgba(r1, 0,   to_rgba(grad_colour[1]))
				cairo_pattern_add_color_stop_rgba(r1, 0.01, to_rgba(grad_colour[2]))
				cairo_pattern_add_color_stop_rgba(r1, 1,   to_rgba(grad_colour[3]))
				cairo_set_source(cr, r1);
				cairo_arc(cr, t.ds.x, t.ds.y, 149*t.ds.csize, TORADIANS,0)
				cairo_fill(cr);
			end

			if t.thc == 0 then
				localhf = 1
			elseif t.thc == 1 then
				localhf = 2
			elseif t.thc == 2 then
				localhf = 2
				sweep_factor = 180
			else
				localhf = 1
			end
			if not sweep_factor then sweep_factor = 0 end

			if t.thc == 1 or t.thc == 2 then
				show_num = 1
			else
				show_num = nil
			end

			-- local cface = 5 --draw_clock_face
			-- hour_factor a roman b marks_main c marks_sec d radius_marks e radius_num
			cfs = {}
			if cface == 1 then 	    -- roman circular out
				cfs = { a=1, b=1, c=R*1.45, d=R*1.5, e=R*1.6, f=R*1.65}
			elseif cface == 2 then	-- roman circular in
				cfs = { a=1, b=1, c=R*1.65, d=R*1.7, e=R*1.8, f=R*1.45}
			elseif cface == 3 then	-- regular out
				cfs = { a=localhf, b=2, c=R*1.45, d=R*1.5, e=R*1.6, f=R*1.73}
			elseif cface == 4 then	-- regular in
				cfs = { a=localhf, b=2, c=R*1.65, d=R*1.7, e=R*1.8, f=R*1.5}
			elseif cface == 5 then	-- regular circular out
				cfs = { a=localhf, b=3, c=R*1.45, d=R*1.5, e=R*1.6, f=R*1.64}
			elseif cface == 6 then	-- regular circular in
				cfs = { a=localhf, b=3, c=R*1.65, d=R*1.7, e=R*1.8, f=R*1.4}
			elseif cface == 7 then	-- regular circular in marks
				cfs = { a=localhf, b=3, c=R*1.7, d=R*1.6, e=R*1.7, f=R*1.6}
			elseif cface == 8 then	-- circular marks only no numbers
				cfs = { a=localhf, b=4, c=R*1.65, d=R*1.7, e=R*1.8, f=0}
			end

			-- print(t.csize)
			hour_factor = cfs.a
			roman = cfs.b
			marks_main = cfs.c
			marks_sec = cfs.d
			radius_marks = cfs.e
			radius_num = cfs.f

			--- fix factors n font sizes for different clock sizes
			local myffact
			-- print(t.csize)
			if t.ds.csize < 0.56667 then
				if t.ds.csize < 0.35556 then
					myffact      = (30*t.ds.csize)
				else
					myffact      = tconcat({(25*t.ds.csize),":bold"})
				end
				-- if roman ~= 4 and show_num ~= 1 then
				if roman ~= 4 then
					marks_main   = R*1.65
					marks_sec    = R*1.55
					radius_marks = marks_main
					if roman == 2 then
						radius_num   = R*1.65
					else
						radius_num   = R*1.52
					end
				-- 	radius_num   = 0
				end
				if show_num == 1 then
					marks_main = R*1.6
					marks_sec    = R*1.7
					-- radius_marks = R*1.7
					radius_marks = R*1.8
					radius_num = 0
				end
			else
				myffact = tconcat({(21*t.ds.csize),":bold"})
			end
			set_font(tconcat({"FreeSerif:",myffact}))
			-- set_font("Times New Roman:"..myffact)

			-- show markers clock face
			-- cairo_set_source_rgba (cr, to_rgba({White,1}))
			cairo_save(cr)
			for i=1,(60*hour_factor) do
				if (i%5==0) then
					rini=marks_main
					-- cairo_set_line_width (cr,(3*t.csize))
					cairo_set_line_width (cr,(2.5*t.ds.csize))
				else
					rini=marks_sec
					cairo_set_line_width (cr,(0.75*t.ds.csize))
				end
				-- cairo_set_source_rgba (cr, to_rgba({White,1}))
				cairo_set_source_rgba (cr, to_rgba(t.ds.ecol))
				cairo_save(cr)
				make_scale_txt2({
					startscale	= 0,
					endscale	= 360,
					maxscale	= (60*hour_factor),
					rout		= radius_marks,
					rin			= rini,
					xval		= t.ds.x,
					yval		= t.ds.y,
					i			= i		})

				if (i%10==0) then
				-- cairo_set_source_rgba (cr, to_rgba({Orchid1,1}))
					cairo_set_source_rgba (cr, to_rgba({Red,0.9}))
					rini=marks_sec
					-- rini=marks_main/1.14
					-- rini=marks_main
				else
					-- cairo_set_source_rgba (cr, to_rgba({White,1}))
					cairo_set_source_rgba (cr, to_rgba(t.ds.ecol))
				end
				cairo_save(cr)
				make_scale_txt2({
					startscale	= 0,
					endscale	= 360,
					maxscale	= (60*hour_factor),
					rout		= radius_marks,
					-- rout		= 300,
					rin			= rini,
					xval		= t.ds.x,
					yval		= t.ds.y,
					i			= i		})
			end
			cairo_stroke(cr)

			-- cairo_set_source_rgba (cr, to_rgba({White,1}))
			cairo_set_source_rgba (cr, to_rgba(t.ds.ecol))
			cairo_save(cr)
			-- show values
			if roman == 1 then
				local degs1={"I ","II","III","IV","V ","VI","VII","VIII","IX","X ","XI","XII"}
				cairo_save(cr)
				local horiz=t.ds.x
				local verti=t.ds.y
				local radi=radius_num
				for i=1,(12*hour_factor) do
					local text = degs1[i]
					local start = (((30*i)/hour_factor)-5)
					if i == 1  then start = start+4   end
					if i >= 3  then start = start-2 end
					if i == 5  then start = start+4 end
					if i >= 6  then start = start+1   end
					if i == 10  then start = start+3.5 end
					local finish=(start-3)+((string.len(text))*4.5)
					circlewriting2(text, radi, horiz, verti, start, finish)
				end
			elseif roman == 2 then
				local degs1={}
				for i=1,(12*hour_factor) do
					degs1[i] = i
				end
				cairo_save(cr)
				for i=1,#degs1 do
					make_scale_txt2({
						startscale	= (sweep_factor+30/hour_factor),
						-- startscale	= (30/hour_factor),
						endscale	= 360,
						maxscale	= #degs1,
						trout		= radius_num,
						text		= degs1[i],
						dotext		= 1,
						squeeze		= 1,
						xval		= t.ds.x,
						yval		= t.ds.y,
						i			= i-1	})
				end
			elseif roman == 3 then
				local degs1={}
				for i=1,(12*hour_factor) do
					degs1[i] = tconcat({i,' '})
					-- print(i)
				end
				local horiz=t.ds.x
				local verti=t.ds.y
				local radi=radius_num
				for i=1,(12*hour_factor) do
					local text = degs1[i]
					-- local start = (((30*i)/hour_factor)-2)
					local start = ((((sweep_factor*2)+30*i)/hour_factor)-2)
					-- print(sweep_factor)
					if i >= 10 then start = start-2   end
					local finish=(start-2)+((string.len(text))*4)
					circlewriting2(text, radi, horiz, verti, start, finish)
				end
				cairo_save(cr)
			end
		end
	end 	-- end of draw_clock_face

	local show_gears       = 1

	local tconcat = tconcat

	if vala.k then vala.k = tonum(vala.k) end
	if vala.k == 1 then
		vala.b = vala.b or tconcat({Lime,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 2 then
		vala.b = vala.b or tconcat({Lime,':0.65'})
		vala.i = vala.i or tconcat({Magenta,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 3 then
		vala.b = vala.b or tconcat({Lime,':1::',Lime,':1::',MidnightBlue,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
	elseif vala.k == 4 then
		vala.b = vala.b or tconcat({Lime,':0.45::',Lime,':1::',MidnightBlue,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
	elseif vala.k == 5 then
		vala.b = vala.b or tconcat({Cyan,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 6 then
		vala.b = vala.b or tconcat({Cyan,':0.65'})
		vala.i = vala.i or tconcat({Magenta,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 7 then
		vala.b = vala.b or tconcat({Cyan,':1::',Cyan,':1::',MidnightBlue,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
	elseif vala.k == 8 then
		vala.b = vala.b or tconcat({Cyan,':0.45::',Cyan,':1::',MidnightBlue,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
	elseif vala.k == 9 then
		vala.b = vala.b or tconcat({MidnightBlue,':1'})
		vala.a = vala.a or 7
		vala.h = vala.h or 10
	elseif vala.k == 10 then
		vala.b = vala.b or tconcat({MidnightBlue,':0.5'})
		vala.a = vala.a or 7
		vala.h = vala.h or 10
	elseif vala.k == 11 then
		vala.b = vala.b or tconcat({Yellow,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 12 then
		vala.b = vala.b or tconcat({Yellow,':0.65'})
		vala.i = vala.i or tconcat({Magenta,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 13 then
		vala.b = vala.b or tconcat({Yellow,':1::',Yellow,':1::',SaddleBrown,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
	elseif vala.k == 14 then
		vala.b = vala.b or tconcat({Yellow,':0.45::',Yellow,':1::',SaddleBrown,':1'})
		vala.i = vala.i or tconcat({Magenta,':1'})
	elseif vala.k == 15 then
		vala.b = vala.b or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 7
		vala.h = vala.h or 10
	elseif vala.k == 16 then
		vala.b = vala.b or tconcat({SaddleBrown,':0.5'})
		vala.a = vala.a or 7
		vala.h = vala.h or 10
	elseif vala.k == 17 then
		vala.b = vala.b or '0xffbbff:1'
		vala.i = vala.i or tconcat({Yellow,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 18 then
		vala.b = vala.b or '0xffbbff:0.65'
		vala.i = vala.i or tconcat({Yellow,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 19 then
		vala.b = vala.b or '0xffbbff:1::0xffbbff:1::0x810541:1'
		vala.i = vala.i or tconcat({Yellow,':1'})
	elseif vala.k == 20 then
		vala.b = vala.b or '0xffbbff:0.45::0xffbbff:1::0x810541:1'
		vala.i = vala.i or tconcat({Yellow,':1'})
	elseif vala.k == 21 then
		vala.b = vala.b or '0x810541:1'
		vala.i = vala.i or tconcat({Yellow,':1'})
	elseif vala.k == 22 then
		vala.b = vala.b or '0x810541:0.5'
		vala.i = vala.i or tconcat({Yellow,':1'})
	elseif vala.k == 23 then
		vala.b = vala.b or tconcat({DarkGold,':1'})
		vala.i = vala.i or tconcat({Blue,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 24 then
		vala.b = vala.b or tconcat({DarkGold,':0.65'})
		vala.i = vala.i or tconcat({Blue,':1'})
		vala.e = vala.e or tconcat({Blue,':1'})
	elseif vala.k == 25 then
		vala.b = vala.b or tconcat({DarkGold,':1::',DarkGold,':1::',Black,':0.8'})
		vala.i = vala.i or tconcat({Yellow,':1'})
	elseif vala.k == 26 then
		vala.b = vala.b or tconcat({DarkGold,':0.45::',DarkGold,':1::',Black,':0.8'})
		vala.i = vala.i or tconcat({Yellow,':1'})
	elseif vala.k == 27 then
		vala.b = vala.b or tconcat({Black,':1'})
		vala.e = vala.e or tconcat({Lime,':1'})
		vala.c = vala.c or tconcat({Magenta,':1'})
		vala.i = vala.i or tconcat({Gold,':1'})
		vala.a = vala.a or 3
		vala.h = vala.h or 6
	elseif vala.k == 28 then
		vala.b = vala.b or tconcat({White,':1'})
		vala.e = vala.e or tconcat({Black,':1'})
		vala.i = vala.i or tconcat({RoyalBlue,':1'})
		vala.a = vala.a or 3
		vala.h = vala.h or 6
	elseif vala.k == 29 then
		vala.f = vala.f or 9
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
	elseif vala.k == 30 then
		vala.f = vala.f or 10
		vala.b = vala.b or '0xfff1e4:1'
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
	elseif vala.k == 31 then
		vala.f = vala.f or 11
		vala.b = vala.b or tconcat({White,':1'})
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
	elseif vala.k == 32 then
		vala.f = vala.f or 12
		vala.b = vala.b or tconcat({Grey81,':1'})
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
	elseif vala.k == 33 then
		vala.f = vala.f or 13
		vala.b = vala.b or '0xe4e4e4:1'
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
	elseif vala.k == 34 then
		vala.f = vala.f or 14
		vala.b = vala.b or '0xe4e4e4:1'
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
	elseif vala.k == 35 then
		vala.f = vala.f or 15
		-- vala.b = vala.b or '0xE8EBFA:1'
		vala.b = vala.b or tconcat({Black,':0.77'})
		vala.i = vala.i or tconcat({Yellow,':1'})
		vala.a = vala.a or 7
		vala.h = vala.h or 11
		vala.x = vala.x or 0
		vala.y = vala.y or 0
		vala.u = vala.u or 1
		vala.l = vala.l or 72
		vala.m = vala.m or 1
	elseif vala.k == 36 then
		vala.f = vala.f or 16
		vala.b = vala.b or tconcat({White,':1'})
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
		vala.u = vala.u or 2
	elseif vala.k == 37 then
		vala.f = vala.f or 17
		vala.b = vala.b or tconcat({White,':1'})
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
		vala.u = vala.u or 1
	elseif vala.k == 38 then
		vala.f = vala.f or 18
		vala.b = vala.b or tconcat({White,':1'})
		vala.i = vala.i or tconcat({SaddleBrown,':1'})
		vala.a = vala.a or 5
		vala.h = vala.h or 6
		vala.x = vala.x or 0
		vala.y = vala.y or 0
		vala.u = vala.u or 1
	elseif vala.k == 39 then
		vala.f = vala.f or 19
		vala.i = vala.i or tconcat({Yellow,':1'})
		vala.c = vala.c or tconcat({Orange3,':1'})
		vala.a = vala.a or 8
		vala.h = vala.h or 11
		vala.x = vala.x or 0
		vala.y = vala.y or 0
		vala.l = vala.l or 123
		show_gears = 0
	elseif vala.k == 40 then
		vala.f = vala.f or 20
		vala.i = vala.i or tconcat({Yellow,':1'})
		vala.c = vala.c or tconcat({Orange3,':1'})
		vala.a = vala.a or 8
		vala.h = vala.h or 11
		vala.x = vala.x or 0
		vala.y = vala.y or 0
		vala.l = vala.l or 123
		show_gears = 0
	else
		vala.b = vala.b or tconcat({DarkGold,':0.45::',DarkGold,':1::',Black,':1'})
	end

	vala.a = vala.a or 1
	vala.h = vala.h or 6
	vala.f = vala.f or 5
	vala.l = vala.l or 115
	vala.m = vala.m or 0.85
	-- vala.m = vala.m or 2

	-- print(vala.m)

--[[
	default option in [] brackets at the end of option
	required options
		vala.s - widget size pixels [150]
		vala.p - widget position pixels [0]
		vala.n - widget name *clock*    [0]
	clock styles handled with -k option
		vala.k - Kind/style of clock    [1]
	following are handled by -k style option
		vala.h - image arrows hours n minutes  [6]
		vala.f - image Clock face image to use [1]
		vala.g - image Clock face colour to use [White ..":1"]
		vala.a - what kind of seconds pointer to use 0 for no arrow 1,2,3,4 [1]
				 1=Off center small seconds ring,
				 2=dot at the seconds markers
				 3=sweep line at the seconds markers
				 4=regular seconds pointer,
				 5=regular seconds pointer with sweep line from 4,
				 6=regular seconds pointer with radar sweep.
				 7=regular seconds pointer with radar sweep.
		vala.r - colour small ring seconds [Black ..":1"]
		vala.c - colour seconds hand       [Red ..":0.75"]
		vala.b - colour background of clock [White ..":0.5"]
		vala.i - hours min arrow colour
		vala.d - colour dial       [...]
		vala.e - colour of text n markers face 1 to 8       [...]
		vala.u - 0 for 12 hr, 1 for 24 hr, 2 for reverse 24 hr [0]
		vala.l - distance of seconds indicator for dot [...]
		vala.m - distance of hr n min indicator [...]
		vala.y - show/hide ampm - is automatic - does not show in 24 hour clock
		vala.x - show/hide day date
		j o q t v x y


--]]
	local pxo          = vala.lwx or 0                -- posn xaxis
	local pyo          = vala.lwy or 0                -- posn yaxis
	local base_size    = tonum(vala.s)   or 150    -- widget size pixels
	local show_seconds = tonum(vala.a)   or 1      -- style seconds 0=no arrow 1,2,3,4
	local ipath        = tconcat({vala.imgpath,'/lua_clock/'})   -- path to clock face
	local clock_arrows = tonum(vala.h)   or 6      -- style of hour min arrows
	local arrow_colour = vala.i   or tconcat({Lime,':1'})       -- colour hour min arrows
	local cface_image  = tonum(vala.f)   or 1      -- clock face image
	local dial_colour  = vala.d   or nil              -- colour dial
	local scolour1     = vala.c or tconcat({Red,':1'})         -- colour seconds arrow
	local rcolour1     = vala.r or tconcat({Black,':1'})       -- colour seconds ring small
	local bcolour1     = vala.b or tconcat({White,':0.5'})     -- colour background
	local ecolour1     = vala.e or tconcat({White,':1'})       -- colour background
	local thc          = tonum(vala.u) or nil      -- 0 for 12 hr, 1 for 24 hr,
													  -- 2 for reverse 24 hr [0]
	local clock_style  = tonum(vala.k) or 1        -- kind / style of clock
	local clock_hand_size = tonum(vala.m) or 1     -- a decimal factor to change length
													  -- of hour and minute clock hands
	local line_width = tonum(vala.w)               -- line thickness
	local show_ampm  = tonum(vala.y) or 1          -- Show/hide am pm
	local show_dd    = tonum(vala.x) or 1          -- Show/hide day date

	-- local clock_face_image = 'face'..cface_image..'.png'
	local center_gear      = 'gear1.png'
	local top_left_gear    = 'gear2.png'
	local bottom_gear      = 'gear7.png'
	local top_right_gear   = 'gear1.png'
	local bottom_right_gear = 'gear3.png'

	if base_size <= 110 then
		line_width = base_size * 0.02
	elseif base_size <= 200 then
		line_width = base_size * 0.01
	else
		line_width = 2
	end

	if thc == 0 then thc = nil end
	-- if cface_image > 19 then cface_image = 9 end

	-- print(bcolour1)

	local scolour2  = wxsplit(scolour1,":")
	local rcolour2  = wxsplit(rcolour1,":")
	local ecolour2  = wxsplit(ecolour1,":")
	arrow_colour  = wxsplit(arrow_colour,":")

	-- base_size = 500
	-- show_seconds = 1
	local max_clock_size = 310
	local clock_size = base_size / max_clock_size
	local px = (pxo+(clock_size*151))
	-- local py = (pyo+(clock_size*150))
	local py = (pyo+(clock_size*160))


	-- clock hands
	local secfact
	if clock_size < 0.5 then
		secfact = 4
	else
		secfact = 2
	end

	-- clock bezel ##############################################
	cairo_save(cr)
	make_bezel({ bezel_size = base_size*1.08, px = px, py = py })
	cairo_restore(cr)

	---------------------------------------------------------------
	-- print(show_seconds)

	local line_width = secfact*clock_size*line_width
	local arc_thickness = arc_thickness1 or line_width * 1.25

	if dial_colour then
		dial_colour = wxsplit(dial_colour,":")
	end

	-- common values for pointer options
	local ds = {
		x      =  px,
		y      =  py,
		csize  =  clock_size,
		scol   =  scolour2,
		rcol   =  rcolour2,
		ecol   =  ecolour2,
		line_width    = line_width,
		ip            = ipath,
		arc_thickness = arc_thickness,
		style         = show_seconds,
		thc           = thc,
		show_sweep    = 1,
		hm_arrows     = clock_arrows,
	}

	-- show gears
	if show_gears == 1 then
		-- top left gear
		run_gear({
			x          =  px-(40*clock_size),
			y          =  py-(28*clock_size),
			file       =  top_left_gear,
			max        =  60,
			scale      =  (clock_size * 0.55),
			dir        =  -1,
			tick       =  true,
			ip         =  ipath   })
		-- bottom gear
		run_gear({
			x          =  px+(0*clock_size),
			y          =  py+(49.5*clock_size),
			file       =  bottom_gear,
			max        =  60,
			scale      =  (clock_size * 0.3),
			dir        =  1,
			ip         =  ipath   })
		-- top right gear
		run_gear({
			x          =  px+(33*clock_size),
			y          =  py-(28*clock_size),
			scale      =  (clock_size * 0.55),
			file       =  top_right_gear,
			max        =  300,
			dir        =  -1,
			ip         =  ipath   })
		-- bottom right gear
		run_gear({
			x          =  px+(31.5*clock_size),
			y          =  py+(31*clock_size),
			file       =  bottom_right_gear,
			dir        =  -1,
			scale      =  (clock_size * 0.45),
			ip         =  ipath   })
		-- center gear
		run_gear({
			x      =  px,
			y      =  py,
			file   =  center_gear,
			scale  =  (clock_size * 0.48),
			ip     =  ipath })
	end


	draw_clock_face({
		ds      =  ds,
		thc     =  thc,
		bcolour =  bcolour1,
		dial_colour   = dial_colour,
		file    =  cface_image,
		length  =  clock_size,
	})

	-- print(show_seconds)
	-- show_seconds = 4
	if show_seconds == 1 then
		ds.y      =  ds.y+(50*clock_size)	-- change ds.y show seconds at offcenter
		draw_seconds({
			ds      = ds,
			ch_indi = 6,
			length  =  (clock_size * 25)
		})
		ds.y      =  ds.y-(50*clock_size)	-- reset ds.y show seconds at offcenter
	elseif  show_seconds == 2 or
			show_seconds == 3  then
		draw_seconds({
			ds     = ds,
			length =  (clock_size * (vala.l or 120) )  })
	end

	-- print(show_dd)

	draw_clock_hands({
		ds         =  ds,
		-- m_file     =  min_hand,
		-- h_file     =  hour_hand,
		m_scale    =  (clock_size * 0.9 * clock_hand_size),
		h_scale    =  (clock_size * 0.7 * clock_hand_size),
		arrow_colour  =  arrow_colour,
		show_ap    =  show_ampm,
		length     =  (clock_size * 25),
		show_dd    =  show_dd,
	})

	if  show_seconds == 4 or
		show_seconds == 5 or
		show_seconds == 6 or
		show_seconds == 7 or
		show_seconds == 8 then
		draw_seconds({
			ds        = ds,
			sweep_colour  =  arrow_colour,
			length =  (clock_size * (vala.l or 120) )  })
	end

	if ds.style ~= 3 then
		cairo_set_source_rgba(cr,0.5,0.7,0,1)
		cairo_arc(cr, px, py, (clock_size * 4), TORADIANS, 0)
		cairo_stroke(cr)
	end
end --end do_clock()

function conky_main(...)		------------ {{{
	if not conky_window then return end
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
	cr = cairo_create(cs)


	if (tonum(conky_parse("${updates}")) % 10) == 3 then
		local conf_name = tconcat({'/tmp/conkywx_tmp_',conky_config:match("([^/]+)$")})
		local uint = ExecInfo({ rfile = conf_name })
		if uint then
			conky_set_update_interval(uint)
			os.remove(conf_name)
		end
	end

	local val,val1,vala = {},{},{}

	local odata = {...}

	if next(odata) then
		local mdata = tconcat(odata,' ')
		mdata = tconcat({" ",mdata})

		local val = wxsplit(mdata,'%s%-%l')

		ma1={}
		for id in mdata:gmatch("%s%-%l") do
			id = id:match( "(%l)" )
			-- tinsert( ma1, id)
			ma1[#ma1 + 1] = id
		end
		if next(ma1) then
			for b=1,#ma1 do
				if val[1] then val[1]=string.sub(val[1],3) end
				if val[b] then val[b]=val[b]:match("^%s*(.-)%s*$") end
				vala[ma1[b]] = val[b]
			end
		else
			error("\nNot valid options on command line conkywx lua!!!\nPlease check the lua command line...\n")
			-- os.exit()
		end
	else
		error( "\nNo lua command line options given to conkywx lua!!!\n")
		-- os.exit()
	end

	-- vala["imgpath"] = string.sub(debug.getinfo(1).source, 2, -16) .. "images/lua_windvane"
	local ip11 = string.sub(debug.getinfo(1).source, 2, -16)
	vala["imgpath"] = tconcat({ip11,"images"})

	-----------------------------------------------

	if next(vala) then
		if vala.p then
			local wxs = wxsplit(vala.p,",")
			local lwx = wxs[1]
			local lwy = wxs[2]
			vala.lwx = lwx:match( "^%s*(.-)%s*$" )
			vala.lwy = lwy:match( "^%s*(.-)%s*$" )
		else
			vala.lwx,vala.lwy=0,0
		end

		if     vala.n == 'windvane'    then do_windvane(vala)
		elseif vala.n == 'showcond'    then do_showcond(vala)
		elseif vala.n == 'thermometer' then	do_thermometer(vala)
		elseif vala.n == 'wxgraph'     then do_wxgraph(vala)
		elseif vala.n == 'background'  then do_background(vala)
		elseif vala.n == 'bargraph'	   then bargraph_styles(vala)
		elseif vala.n == 'barometer'   then do_barometer(vala)
		elseif vala.n == 'anemometer'  then do_anemometer(vala)
		elseif vala.n == 'music_sort'  then do_music_sort(vala)
		elseif vala.n == 'scroller'    then do_scroller(vala)
		elseif vala.n == 'vumeter'     then do_vumeter(vala)
		elseif vala.n == 'clock'       then do_clock(vala)
		end

	else
		error("\nUnable to create vala table.\nSomething wrong with the lua command line...\n")
	end

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
	cr=nil
	return ""
end-- end main function		------------ }}}


--[[
	cat /sys/devices/platform/coretemp.0/hwmon/hwmon0/temp1_input

--]]
