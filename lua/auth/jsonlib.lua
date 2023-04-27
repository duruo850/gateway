local jsonlib={}
function jsonlib:dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. lib:dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
function jsonlib:json(o)
	local json = require('cjson')
	return json.encode(o)
end
function jsonlib:json2obj(o)
	local json = require('cjson')
	return json.decode(o)
end
return jsonlib