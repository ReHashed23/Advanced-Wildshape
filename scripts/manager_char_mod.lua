-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
OOB_MSGTYPE_PROCESS_CHANGE = "process_change";
OOB_MSGTYPE_RESTORE_CHANGE = "restore_change";
OOB_MSGTYPE_FILTER_DB = "filter_db";

--Data retrieval fields
local tCompiledWildshapeList = {};
local tCompiledPolymorphList = {};
local tCompiledTrueList = {}
local tCompiledShapechangeList = {};
local tCompiledDisguiseList = {};
local tEquippedList = {};
local sWildshapeMovementFilter, sWildshapeCRFilter;
local sPolymorphMovementFilter, sPolymorphCRFilter;
local sTrueMovementFilter, sTrueCRFilter;
local sShapechangeTypeFilter, sShapechangeSizeFilter;
local sDisguiseTypeFilter, sDisguiseSizeFilter;
local nodeForm;
local fApplyDamage;
local bShapechanged;
local tListOfModulesToLoad = {"blank"};
local tListOfEffects = {
	"Blinded",
	"Charmed",
	"Cursed",
	"Encumbered",
	"Grappled",
	"Intoxicated",
	"Paralyzed",
	"Poisoned",
	"Restrained",
	"Stunned",
	"Unconscious",
	"Turned",
	"Stable",
	"Prone",
	"Petrified",
	"Invisible",
	"Incapacitated",
	"Frightened",
	"Deafened"
};
local tListOfCoreBooks = {
	"DD PHB Deluxe",
	"DD Dungeon Masters Guide",
	"DD MM Monster Manual",
	"DD Mordenkainen's Tome of Foes",
	"DD Volos Guide to Monsters"
};

function onInit()
	OptionsManager.registerOption2(
        "ShapeStatShare",
        false,
        "option_header_simple_shapechange",
        "option_label_share",
        "option_entry_cycler",
        {
            labels = "option_shape_true",
            values = "true",
            baselabel = "option_shape_false",
            baseval = "false",
            default = "false"
        }
    );
	-- OptionsManager.registerOption2(
        -- "MoreThan5",
        -- false,
        -- "option_header_simple_shapechange",
        -- "option_label_core_books",
        -- "option_entry_cycler",
        -- {
            -- labels = "option_shape_true",
            -- values = "true",
            -- baselabel = "option_shape_false",
            -- baseval = "false",
            -- default = "false"
        -- }
    -- );
	if User.isHost() then
		Module.addEventHandler("onModuleLoad", addModuleData);
	end
	OOBManager.registerOOBMsgHandler("process_change", self.storePlayerData);
	OOBManager.registerOOBMsgHandler("restore_change", self.restorePlayerData);
	OOBManager.registerOOBMsgHandler("filter_db", self.filterDB);
	fApplyDamage = ActionDamage.applyDamage;
	ActionDamage.applyDamage = myApplyDamage;
end

--Compile AW DB
function addModuleData(sModule)
	local nodeShapechanges = DB.createChild(DB.getRoot(), "shapechange_forms");
	DB.setPublic(nodeShapechanges, true);
	for _,vCoreBook in ipairs(tListOfCoreBooks) do
	Debug.console(vCoreBook);
	Debug.console(sModule);
		if vCoreBook == sModule then
			local nodeRoot = DB.getRoot(sModule);
			for _, vNode in ipairs(DB.getChildList(nodeRoot)) do
				local sNodePath = DB.getPath(vNode);
				if sNodePath:find("reference") then
					for _, vListNode in ipairs(DB.getChildList(vNode)) do
						local sListPath = DB.getPath(vListNode);
						if sListPath:find("npcdata") then
							for _, vNPC in ipairs(DB.getChildList(vListNode)) do
								if DB.getPath(vNPC):find("template") then return; end
								local nodeShapechange = DB.createChild(nodeShapechanges, DB.getValue(vNPC, "name"));
								DB.createChild(nodeShapechange, "noderef", "string");
								DB.setValue(nodeShapechange, "noderef", "string", DB.getPath(vNPC));
							end
						end
					end
				end
			end
			
			return;
		end
	end
	table.insert(tListOfModulesToLoad, #tListOfModulesToLoad, sModule);
end
--Blow Up the DB
function addMoreModuleData()
	local nodeShapechanges = DB.findNode("shapechange_forms");
	for _,vCoreBook in ipairs(tListOfModulesToLoad) do
		local nodeRoot = DB.getRoot(vCoreBook);
		for _, vNode in ipairs(DB.getChildList(nodeRoot)) do
			local sNodePath = DB.getPath(vNode);
			if sNodePath:find("reference") then
				for _, vListNode in ipairs(DB.getChildList(vNode)) do
					local sListPath = DB.getPath(vListNode);
					if sListPath:find("npcdata") then
						for _, vNPC in ipairs(DB.getChildList(vListNode)) do
							if DB.getPath(vNPC):find("template") then return; end
							local nodeShapechange = DB.createChild(nodeShapechanges, DB.getValue(vNPC, "name"));
							DB.createChild(nodeShapechange, "noderef", "string");
							DB.setValue(nodeShapechange, "noderef", "string", DB.getPath(vNPC));
						end
					end
				end
			end
		end
	end
end

--Show available forms with filters applied [note]May need to duplicate this section for players however still having the issue of player not being able to get monster data from source.
function filterWildshapeDB()
	tCompiledWildshapeList = {};
	if sWildshapeMovementFilter ~= nil then
		if sWildshapeMovementFilter:match("has") then
			sWildshapeMovementFilter = sWildshapeMovementFilter:sub(4);
			sWildshapeMovementFilter = sWildshapeMovementFilter:gsub(" ", "");
		end
	end
	
	if sWildshapeCRFilter ~= nil then
		if string.match(sWildshapeCRFilter, "1/4") then
			sWildshapeCRFilter = .25;
		elseif string.match(sWildshapeCRFilter, "1/2") then
			sWildshapeCRFilter = .5;
		elseif string.match(sWildshapeCRFilter, "1/8") then
			sWildshapeCRFilter = .125
		else
			sWildshapeCRFilter = tonumber(sWildshapeCRFilter);
		end
	end
	
	for _,vShapechange in ipairs(DB.getChildList(DB.getRoot(), "shapechange_forms")) do
		--Filter out desired characteristics before inserting
		local formToFilter;
		if User.isHost() then
			formToFilter = DB.findNode(DB.getValue(vShapechange, "noderef"));
		else
			self.OOBFilterDB(DB.getValue(vShapechange, "noderef"));
			formToFilter = self.getNode();
		end
		Debug.chat(formToFilter);
		if DB.getValue(formToFilter, "type"):match("beast") then
			local sBeastSpeed = DB.getValue(formToFilter, "speed"):lower();
			local sBeastCR = DB.getValue(formToFilter, "cr");
			local beastName = DB.getValue(formToFilter, "name");
			beastName = beastName:gsub("_", " ");
			
			if sBeastCR == "1/4" then
				sBeastCR = .25;
			elseif sBeastCR == "1/2" then
				sBeastCR = .5;
			elseif sBeastCR == "1/8" then
				sBeastCR = .125;
			else
				sBeastCR = tonumber(sBeastCR);
			end
			
			if sWildshapeMovementFilter and sWildshapeCRFilter == nil then
				if string.match(sWildshapeMovementFilter, "normal") then
					if string.match(sBeastSpeed, "fly") or string.match(sBeastSpeed, "swim") then
						
					else
						table.insert(tCompiledWildshapeList, beastName);
					end
				elseif string.match(sBeastSpeed, sWildshapeMovementFilter) then
					table.insert(tCompiledWildshapeList, beastName);
				end
			elseif sWildshapeMovementFilter and sWildshapeCRFilter then
				if string.match(sWildshapeMovementFilter, "normal") then
					if sBeastCR <= sWildshapeCRFilter then
						if (string.match(sBeastSpeed, "fly") or string.match(sBeastSpeed, "swim")) then
							
						else
							table.insert(tCompiledWildshapeList, beastName);
						end
					end
				else
					if string.match(sBeastSpeed, sWildshapeMovementFilter) then
						if sBeastCR <= sWildshapeCRFilter then
							if string.match(sBeastSpeed, sWildshapeMovementFilter) then
								table.insert(tCompiledWildshapeList, beastName);
							end
						end
					end
				end
			elseif sWildshapeMovementFilter == nil and sWildshapeCRFilter then
				if sBeastCR <= sWildshapeCRFilter then
					table.insert(tCompiledWildshapeList, beastName);
				end
			elseif sWildshapeCRFilter == nil and sWildshapeMovementFilter == nil then
				table.insert(tCompiledWildshapeList, beastName);
			end
		end
	end
	formToFilter = nil;
	return tCompiledWildshapeList;
end
function filterShapechangeDB()
	tCompiledShapechangeList = {};
		
	for _,vShapechange in ipairs(DB.getChildList(DB.getRoot(), "shapechange_forms")) do
		--Filter out desired characteristics before inserting
		local formToFilter;
		if User.isHost() then
			formToFilter = DB.findNode(DB.getValue(vShapechange, "noderef"));
		else
			self.OOBFilterDB(DB.getValue(vShapechange, "noderef"));
			formToFilter = self.getNode();
		end
		Debug.chat(formToFilter);
		local sBeastType = DB.getValue(formToFilter, "type"):lower();
		local sBeastSize = DB.getValue(formToFilter, "size"):lower();
		local beastName = DB.getValue(formToFilter, "name");
		beastName = beastName:gsub("_", " ");

		if sShapechangeTypeFilter and sShapechangeSizeFilter == nil then
			if string.match(sBeastType, sShapechangeTypeFilter) then
				table.insert(tCompiledShapechangeList, beastName);
			end
		elseif sShapechangeTypeFilter and sShapechangeSizeFilter then
			if string.match(sBeastType, sShapechangeTypeFilter) then
				if string.match(sBeastSize, sShapechangeSizeFilter) then
					table.insert(tCompiledShapechangeList, beastName);
				end
			end
		elseif sShapechangeTypeFilter == nil and sShapechangeSizeFilter then
			if string.match(sBeastSize, sShapechangeSizeFilter) then
				table.insert(tCompiledShapechangeList, beastName);
			end
		elseif sShapechangeSizeFilter == nil and sShapechangeTypeFilter == nil then
			table.insert(tCompiledShapechangeList, beastName);
		end
	end
	formToFilter = nil;
	return tCompiledShapechangeList;
end
function filterPolymorphDB()
	tCompiledPolymorphList = {};
	
	if sPolymorphMovementFilter ~= nil then
		if sPolymorphMovementFilter:match("has") then
			sPolymorphMovementFilter = sPolymorphMovementFilter:sub(4);
			sPolymorphMovementFilter = sPolymorphMovementFilter:gsub(" ", "");
		end
	end
	
	if sPolymorphCRFilter ~= nil then
		if string.match(sPolymorphCRFilter, "1/4") then
			sPolymorphCRFilter = .25;
		elseif string.match(sPolymorphCRFilter, "1/2") then
			sPolymorphCRFilter = .5;
		elseif string.match(sPolymorphCRFilter, "1/8") then
			sPolymorphCRFilter = .125
		else
			sPolymorphCRFilter = tonumber(sPolymorphCRFilter);
		end
	end
	
	for _,vShapechange in ipairs(DB.getChildList(DB.getRoot(), "shapechange_forms")) do
		--Filter out desired characteristics before inserting
		local formToFilter;
		if User.isHost() then
			formToFilter = DB.findNode(DB.getValue(vShapechange, "noderef"));
		else
			self.OOBFilterDB(DB.getValue(vShapechange, "noderef"));
			formToFilter = self.getNode();
		end
		Debug.chat(formToFilter);
		local sBeastSpeed = DB.getValue(formToFilter, "speed"):lower();
		local sBeastCR = DB.getValue(formToFilter, "cr");
		local beastName = DB.getValue(formToFilter, "name");
		beastName = beastName:gsub("_", " ");
		
		if sBeastCR == "1/4" then
			sBeastCR = .25;
		elseif sBeastCR == "1/2" then
			sBeastCR = .5;
		elseif sBeastCR == "1/8" then
			sBeastCR = .125;
		else
			sBeastCR = tonumber(sBeastCR);
		end
		
		if sPolymorphMovementFilter and sPolymorphCRFilter == nil then
			if string.match(sPolymorphMovementFilter, "normal") then
				if string.match(sBeastSpeed, "fly") or string.match(sBeastSpeed, "swim") then
					
				else
					table.insert(tCompiledPolymorphList, beastName);
				end
			elseif string.match(sBeastSpeed, sPolymorphMovementFilter) then
				table.insert(tCompiledPolymorphList, beastName);
			end
		elseif sPolymorphMovementFilter and sPolymorphCRFilter then
			if string.match(sPolymorphMovementFilter, "normal") then
				if sBeastCR <= sPolymorphCRFilter then
					if string.match(sBeastSpeed, "fly") or string.match(sBeastSpeed, "swim") then
					
					else
						table.insert(tCompiledPolymorphList, beastName);
					end
				end
			else
				if string.match(sBeastSpeed, sPolymorphMovementFilter) then
					if sBeastCR <= sPolymorphCRFilter then
						if string.match(sBeastSpeed, sPolymorphMovementFilter) then
							table.insert(tCompiledPolymorphList, beastName);
						end
					end
				end
			end
		elseif sPolymorphMovementFilter == nil and sPolymorphCRFilter then
			if sBeastCR <= sPolymorphCRFilter then
				table.insert(tCompiledPolymorphList, beastName);
			end
		elseif sPolymorphCRFilter == nil and sPolymorphMovementFilter == nil then
			table.insert(tCompiledPolymorphList, beastName);
		end
	end
	formToFilter = nil;
	return tCompiledPolymorphList;
end
function filterTrueDB()
	tCompiledTrueList = {};
	
	if sPolymorphMovementFilter ~= nil then
		if sPolymorphMovementFilter:match("has") then
			sPolymorphMovementFilter = sPolymorphMovementFilter:sub(4);
			sPolymorphMovementFilter = sPolymorphMovementFilter:gsub(" ", "");
		end
	end
	
	if sPolymorphCRFilter ~= nil then
		if string.match(sPolymorphCRFilter, "1/4") then
			sPolymorphCRFilter = .25;
		elseif string.match(sPolymorphCRFilter, "1/2") then
			sPolymorphCRFilter = .5;
		elseif string.match(sPolymorphCRFilter, "1/8") then
			sPolymorphCRFilter = .125
		else
			sPolymorphCRFilter = tonumber(sPolymorphCRFilter);
		end
	end
	
	for _,vShapechange in ipairs(DB.getChildList(DB.getRoot(), "shapechange_forms")) do
		--Filter out desired characteristics before inserting
		local formToFilter;
		if User.isHost() then
			formToFilter = DB.findNode(DB.getValue(vShapechange, "noderef"));
		else
			self.OOBFilterDB(DB.getValue(vShapechange, "noderef"));
			formToFilter = self.getNode();
		end
		Debug.chat(formToFilter);
		local sBeastSpeed = DB.getValue(formToFilter, "speed"):lower();
		local sBeastCR = DB.getValue(formToFilter, "cr");
		local beastName = DB.getValue(formToFilter, "name");
		beastName = beastName:gsub("_", " ");
		
		if sBeastCR == "1/4" then
			sBeastCR = .25;
		elseif sBeastCR == "1/2" then
			sBeastCR = .5;
		elseif sBeastCR == "1/8" then
			sBeastCR = .125;
		else
			sBeastCR = tonumber(sBeastCR);
		end
		
		if sPolymorphMovementFilter and sPolymorphCRFilter == nil then
			if string.match(sPolymorphMovementFilter, "normal") then
				if string.match(sBeastSpeed, "fly") or string.match(sBeastSpeed, "swim") then
					
				else
					table.insert(tCompiledTrueList, beastName);
				end
			elseif string.match(sBeastSpeed, sPolymorphMovementFilter) then
				table.insert(tCompiledTrueList, beastName);
			end
		elseif sPolymorphMovementFilter and sPolymorphCRFilter then
			if string.match(sPolymorphMovementFilter, "normal") then
				if sBeastCR <= sPolymorphCRFilter then
					if string.match(sBeastSpeed, "fly") or string.match(sBeastSpeed, "swim") then
					
					else
						table.insert(tCompiledTrueList, beastName);
					end
				end
			else
				if string.match(sBeastSpeed, sPolymorphMovementFilter) then
					if sBeastCR <= sPolymorphCRFilter then
						if string.match(sBeastSpeed, sPolymorphMovementFilter) then
							table.insert(tCompiledTrueList, beastName);
						end
					end
				end
			end
		elseif sPolymorphMovementFilter == nil and sPolymorphCRFilter then
			if sBeastCR <= sPolymorphCRFilter then
				table.insert(tCompiledTrueList, beastName);
			end
		elseif sPolymorphCRFilter == nil and sPolymorphMovementFilter == nil then
			table.insert(tCompiledTrueList, beastName);
		end
	end
	formToFilter = nil;
	return tCompiledTrueList;
end
function filterDisguiseDB()
	tCompiledDisguiseList = {};
	
	for _,vShapechange in ipairs(DB.getChildList(DB.getRoot(), "shapechange_forms")) do
		--Filter out desired characteristics before inserting
		local formToFilter;
		if User.isHost() then
			formToFilter = DB.findNode(DB.getValue(vShapechange, "noderef"));
		else
			self.OOBFilterDB(DB.getValue(vShapechange, "noderef"));
			formToFilter = self.getNode();
		end
		Debug.chat(formToFilter);
		local sBeastType = DB.getValue(formToFilter, "type"):lower();
		local sBeastSize = DB.getValue(formToFilter, "size"):lower();
		local beastName = DB.getValue(formToFilter, "name");
		beastName = beastName:gsub("_", " ");

		if sDisguiseTypeFilter and sDisguiseSizeFilter == nil then
			if string.match(sBeastType, sDisguiseTypeFilter) then
				table.insert(tCompiledDisguiseList, beastName);
			end
		elseif sDisguiseTypeFilter and sDisguiseSizeFilter then
			if string.match(sBeastType, sDisguiseTypeFilter) then
				if string.match(sBeastSize, sDisguiseSizeFilter) then
					table.insert(tCompiledDisguiseList, beastName);
				end
			end
		elseif sDisguiseTypeFilter == nil and sDisguiseSizeFilter then
			if string.match(sBeastSize, sDisguiseSizeFilter) then
				table.insert(tCompiledDisguiseList, beastName);
			end
		elseif sDisguiseSizeFilter == nil and sDisguiseTypeFilter == nil then
			table.insert(tCompiledDisguiseList, beastName);
		end
	end
	return tCompiledDisguiseList;
end
function filterDB(msgOOB)
	Debug.chat(msgOOB.form);
	nodeForm = DB.findNode(msgOOB.form);
	Debug.chat(nodeForm);
end
function getNode()
	Debug.chat(nodeForm);
	return nodeForm;
end

--Application of filters
function applyWildshapeMovementFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sWildshapeMovementFilter = s;
end
function applyWildshapeCRFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sWildshapeCRFilter = s;
end
function applyPolymorphMovementFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sPolymorphMovementFilter = s;
end
function applyPolymorphCRFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sPolymorphCRFilter = s;
end
function applyTrueMovementFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sTrueMovementFilter = s;
end
function applyTrueCRFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sTrueCRFilter = s;
end
function applyShapechangeTypeFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sShapechangeTypeFilter = s;
end
function applyShapechangeSizeFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sShapechangeSizeFilter = s;
end
function applyDisguiseTypeFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sDisguiseTypeFilter = s;
end
function applyDisguiseSizeFilter(s)
	if s ~= nil then
		s = s:lower();
		if string.match(s, "all") then
			s = nil;
		end
	end
	sDisguiseSizeFilter = s;
end

--Load DB data for forms into preview
function loadWildshape(sShapechangeName, userID)
	if string.find(sShapechangeName, " ") then
		sShapechangeName = sShapechangeName:gsub(" ", "");
	end
	
	local nodeShapechangeDB = DB.findNode("shapechange_forms");
	for _, vShapechange in ipairs(DB.getChildList(nodeShapechangeDB)) do
		local sPath = DB.getValue(vShapechange, "noderef");
		if sPath:find(sShapechangeName:lower()) then
			local shapechange = DB.getChild(userID, "shapechange");
			if shapechange ~= nil then
				DB.deleteNode(DB.findNode(DB.getPath(userID) .. ".shapechange"));
			end
			
			local nodeShapechange = DB.createChild(userID, "shapechange");
			local nodeSPath = DB.findNode(sPath);
			
			DB.createChild(nodeShapechange, "beastHP", "number");
			DB.createChild(nodeShapechange, "beastAC", "number");
			DB.createChild(nodeShapechange, "beastCR", "string");
			DB.createChild(nodeShapechange, "beastName", "string");
			DB.createChild(nodeShapechange, "beastSize", "string");
			DB.createChild(nodeShapechange, "beastSpeed", "string");
			DB.createChild(nodeShapechange, "beastToken", "token");
			
			DB.setValue(nodeShapechange, "beastHP", "number", DB.getValue(nodeSPath, "hp"));
			DB.setValue(nodeShapechange, "beastAC", "number", DB.getValue(nodeSPath, "ac"));
			DB.setValue(nodeShapechange, "beastCR", "string", DB.getValue(nodeSPath, "cr"));
			DB.setValue(nodeShapechange, "beastName", "string", DB.getValue(nodeSPath, "name"));
			DB.setValue(nodeShapechange, "beastSize", "string", DB.getValue(nodeSPath, "size"));
			DB.setValue(nodeShapechange, "beastSpeed", "string", DB.getValue(nodeSPath, "speed"));
			DB.setValue(nodeShapechange, "beastToken", "token", DB.getValue(nodeSPath, "token"));
			
			local nodeBeastAbilities = DB.createChild(nodeShapechange, "beastAbilities")
			local nodeCharAbilities = DB.getChild(userID, "abilities");
			for _, vAbility in ipairs(DB.getChildList(nodeSPath, "abilities")) do
				if DB.getPath(vAbility):find("strength") then
					DB.createChild(nodeBeastAbilities, "strength", "number");
					DB.setValue(nodeBeastAbilities, "strength", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("dexterity") then
					DB.createChild(nodeBeastAbilities, "dexterity", "number");
					DB.setValue(nodeBeastAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("constitution") then
					DB.createChild(nodeBeastAbilities, "constitution", "number");
					DB.setValue(nodeBeastAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("intelligence") then
					DB.createChild(nodeBeastAbilities, "intelligence", "number");
					DB.setValue(nodeBeastAbilities, "intelligence", "number", DB.getValue(DB.getChild(nodeCharAbilities, "intelligence"), "score"));
				end
				if DB.getPath(vAbility):find("wisdom") then
					DB.createChild(nodeBeastAbilities, "wisdom", "number");
					DB.setValue(nodeBeastAbilities, "wisdom", "number", DB.getValue(DB.getChild(nodeCharAbilities, "wisdom"), "score"));
				end
				if DB.getPath(vAbility):find("charisma") then
					DB.createChild(nodeBeastAbilities, "charisma", "number");
					DB.setValue(nodeBeastAbilities, "charisma", "number", DB.getValue(DB.getChild(nodeCharAbilities, "charisma"), "score"));
				end
			end
			
			local nodeActions = DB.createChild(nodeShapechange, "actions");
			for _, vAction in ipairs(DB.getChildList(nodeSPath, "actions")) do
				local actionNode = DB.createChild(nodeActions, DB.getValue(vAction, "name"));
				DB.createChild(actionNode, "name", "string");
				DB.createChild(actionNode, "desc", "string");
				DB.setValue(actionNode, "name", "string", DB.getValue(vAction, "name"));
				DB.setValue(actionNode, "desc", "string", DB.getValue(vAction, "desc"));
			end
			
			local nodeTraitList = DB.createChild(nodeShapechange, "traits");
			for _, vTrait in ipairs(DB.getChildList(nodeSPath, "traits")) do
				local traitNode = DB.createChild(nodeTraitList, DB.getValue(vTrait, "name"));
				DB.createChild(traitNode, "name", "string");
				DB.createChild(traitNode, "desc", "string");
				DB.setValue(traitNode, "name", "string", DB.getValue(vTrait, "name"));
				DB.setValue(traitNode, "desc", "string", DB.getValue(vTrait, "desc"));
			end
			
			bShapechanged = false;
			return nodeShapechange;
		end
	end
end
function loadShapechange(sShapechangeName, userID)
	if string.find(sShapechangeName, " ") then
		sShapechangeName = sShapechangeName:gsub(" ", "");
	end
	
	local nodeShapechangeDB = DB.findNode("shapechange_forms");
	for _, vShapechange in ipairs(DB.getChildList(nodeShapechangeDB)) do
		local sPath = DB.getValue(vShapechange, "noderef");
		if sPath:find(sShapechangeName:lower()) then
			local shapechange = DB.getChild(userID, "shapechange");
			if shapechange ~= nil then
				DB.deleteNode(DB.findNode(DB.getPath(userID) .. ".shapechange"));
			end

			local nodeShapechange = DB.createChild(userID, "shapechange");
			local nodeSPath = DB.findNode(sPath);
			
			DB.createChild(nodeShapechange, "beastHP", "number");
			DB.createChild(nodeShapechange, "beastAC", "number");
			DB.createChild(nodeShapechange, "beastCR", "string");
			DB.createChild(nodeShapechange, "beastName", "string");
			DB.createChild(nodeShapechange, "beastSize", "string");
			DB.createChild(nodeShapechange, "beastSpeed", "string");
			DB.createChild(nodeShapechange, "beastToken", "token");
			
			DB.setValue(nodeShapechange, "beastHP", "number", DB.getValue(nodeSPath, "hp"));
			DB.setValue(nodeShapechange, "beastAC", "number", DB.getValue(nodeSPath, "ac"));
			DB.setValue(nodeShapechange, "beastCR", "string", DB.getValue(nodeSPath, "cr"));
			DB.setValue(nodeShapechange, "beastName", "string", DB.getValue(nodeSPath, "name"));
			DB.setValue(nodeShapechange, "beastSize", "string", DB.getValue(nodeSPath, "size"));
			DB.setValue(nodeShapechange, "beastSpeed", "string", DB.getValue(nodeSPath, "speed"));
			DB.setValue(nodeShapechange, "beastToken", "token", DB.getValue(nodeSPath, "token"));
			
			local nodeBeastAbilities = DB.createChild(nodeShapechange, "beastAbilities")
			local nodeCharAbilities = DB.getChild(userID, "abilities");
			for _, vAbility in ipairs(DB.getChildList(nodeSPath, "abilities")) do
				if DB.getPath(vAbility):find("strength") then
					DB.createChild(nodeBeastAbilities, "strength", "number");
					DB.setValue(nodeBeastAbilities, "strength", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("dexterity") then
					DB.createChild(nodeBeastAbilities, "dexterity", "number");
					DB.setValue(nodeBeastAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("constitution") then
					DB.createChild(nodeBeastAbilities, "constitution", "number");
					DB.setValue(nodeBeastAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("intelligence") then
					DB.createChild(nodeBeastAbilities, "intelligence", "number");
					DB.setValue(nodeBeastAbilities, "intelligence", "number", DB.getValue(DB.getChild(nodeCharAbilities, "intelligence"), "score"));
				end
				if DB.getPath(vAbility):find("wisdom") then
					DB.createChild(nodeBeastAbilities, "wisdom", "number");
					DB.setValue(nodeBeastAbilities, "wisdom", "number", DB.getValue(DB.getChild(nodeCharAbilities, "wisdom"), "score"));
				end
				if DB.getPath(vAbility):find("charisma") then
					DB.createChild(nodeBeastAbilities, "charisma", "number");
					DB.setValue(nodeBeastAbilities, "charisma", "number", DB.getValue(DB.getChild(nodeCharAbilities, "charisma"), "score"));
				end
			end
			
			local nodeActions = DB.createChild(nodeShapechange, "actions");
			for _, vAction in ipairs(DB.getChildList(nodeSPath, "actions")) do
				local actionNode = DB.createChild(nodeActions, DB.getValue(vAction, "name"));
				DB.createChild(actionNode, "name", "string");
				DB.createChild(actionNode, "desc", "string");
				DB.setValue(actionNode, "name", "string", DB.getValue(vAction, "name"));
				DB.setValue(actionNode, "desc", "string", DB.getValue(vAction, "desc"));
			end
			
			local nodeTraitList = DB.createChild(nodeShapechange, "traits");
			for _, vTrait in ipairs(DB.getChildList(nodeSPath, "traits")) do
				local traitNode = DB.createChild(nodeTraitList, DB.getValue(vTrait, "name"));
				DB.createChild(traitNode, "name", "string");
				DB.createChild(traitNode, "desc", "string");
				DB.setValue(traitNode, "name", "string", DB.getValue(vTrait, "name"));
				DB.setValue(traitNode, "desc", "string", DB.getValue(vTrait, "desc"));
			end
			
			bShapechanged = false;
			return nodeShapechange;
		end
	end
end
function loadPolymorph(sShapechangeName, userID)
	if string.find(sShapechangeName, " ") then
		sShapechangeName = sShapechangeName:gsub(" ", "");
	end
	
	local nodeShapechangeDB = DB.findNode("shapechange_forms");
	for _, vShapechange in ipairs(DB.getChildList(nodeShapechangeDB)) do
		local sPath = DB.getValue(vShapechange, "noderef");
		if sPath:find(sShapechangeName:lower()) then
			local shapechange = DB.getChild(userID, "shapechange");
			if shapechange ~= nil then
				DB.deleteNode(DB.getPath(userID) .. ".shapechange");
			end

			local nodeShapechange = DB.createChild(userID, "shapechange");
			local nodeSPath = DB.findNode(sPath);
			
			DB.createChild(nodeShapechange, "beastHP", "number");
			DB.createChild(nodeShapechange, "beastAC", "number");
			DB.createChild(nodeShapechange, "beastCR", "string");
			DB.createChild(nodeShapechange, "beastName", "string");
			DB.createChild(nodeShapechange, "beastSize", "string");
			DB.createChild(nodeShapechange, "beastSpeed", "string");
			DB.createChild(nodeShapechange, "beastToken", "token");
			
			DB.setValue(nodeShapechange, "beastHP", "number", DB.getValue(nodeSPath, "hp"));
			DB.setValue(nodeShapechange, "beastAC", "number", DB.getValue(nodeSPath, "ac"));
			DB.setValue(nodeShapechange, "beastCR", "string", DB.getValue(nodeSPath, "cr"));
			DB.setValue(nodeShapechange, "beastName", "string", DB.getValue(nodeSPath, "name"));
			DB.setValue(nodeShapechange, "beastSize", "string", DB.getValue(nodeSPath, "size"));
			DB.setValue(nodeShapechange, "beastSpeed", "string", DB.getValue(nodeSPath, "speed"));
			DB.setValue(nodeShapechange, "beastToken", "token", DB.getValue(nodeSPath, "token"));

			local nodeBeastAbilities = DB.createChild(nodeShapechange, "beastAbilities")
			for _, vAbility in ipairs(DB.getChildList(nodeSPath, "abilities")) do
				if DB.getPath(vAbility):find("strength") then
					DB.createChild(nodeBeastAbilities, "strength", "number");
					DB.setValue(nodeBeastAbilities, "strength", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("dexterity") then
					DB.createChild(nodeBeastAbilities, "dexterity", "number");
					DB.setValue(nodeBeastAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("constitution") then
					DB.createChild(nodeBeastAbilities, "constitution", "number");
					DB.setValue(nodeBeastAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("intelligence") then
					DB.createChild(nodeBeastAbilities, "intelligence", "number");
					DB.setValue(nodeBeastAbilities, "intelligence", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("wisdom") then
					DB.createChild(nodeBeastAbilities, "wisdom", "number");
					DB.setValue(nodeBeastAbilities, "wisdom", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("charisma") then
					DB.createChild(nodeBeastAbilities, "charisma", "number");
					DB.setValue(nodeBeastAbilities, "charisma", "number", DB.getValue(vAbility, "score"));
				end
			end

			local nodeActions = DB.createChild(nodeShapechange, "actions");
			for _, vAction in ipairs(DB.getChildList(nodeSPath, "actions")) do
				local actionNode = DB.createChild(nodeActions, DB.getValue(vAction, "name"));
				DB.createChild(actionNode, "name", "string");
				DB.createChild(actionNode, "desc", "string");
				DB.setValue(actionNode, "name", "string", DB.getValue(vAction, "name"));
				DB.setValue(actionNode, "desc", "string", DB.getValue(vAction, "desc"));
			end

			local nodeTraitList = DB.createChild(nodeShapechange, "traits");
			for _, vTrait in ipairs(DB.getChildList(nodeSPath, "traits")) do
				local traitNode = DB.createChild(nodeTraitList, DB.getValue(vTrait, "name"));
				DB.createChild(traitNode, "name", "string");
				DB.createChild(traitNode, "desc", "string");
				DB.setValue(traitNode, "name", "string", DB.getValue(vTrait, "name"));
				DB.setValue(traitNode, "desc", "string", DB.getValue(vTrait, "desc"));
			end
			
			bShapechanged = false;
			return nodeShapechange;
		end
	end
end
function loadTrue(sShapechangeName, userID)
	if string.find(sShapechangeName, " ") then
		sShapechangeName = sShapechangeName:gsub(" ", "");
	end
	
	local nodeShapechangeDB = DB.findNode("shapechange_forms");
	for _, vShapechange in ipairs(DB.getChildList(nodeShapechangeDB)) do
		local sPath = DB.getValue(vShapechange, "noderef");
		if sPath:find(sShapechangeName:lower()) then
			local shapechange = DB.getChild(userID, "shapechange");
			if shapechange ~= nil then
				DB.deleteNode(DB.getPath(userID) .. ".shapechange");
			end

			local nodeShapechange = DB.createChild(userID, "shapechange");
			local nodeSPath = DB.findNode(sPath);
			
			DB.createChild(nodeShapechange, "beastHP", "number");
			DB.createChild(nodeShapechange, "beastAC", "number");
			DB.createChild(nodeShapechange, "beastCR", "string");
			DB.createChild(nodeShapechange, "beastName", "string");
			DB.createChild(nodeShapechange, "beastSize", "string");
			DB.createChild(nodeShapechange, "beastSpeed", "string");
			DB.createChild(nodeShapechange, "beastToken", "token");
			
			DB.setValue(nodeShapechange, "beastHP", "number", DB.getValue(nodeSPath, "hp"));
			DB.setValue(nodeShapechange, "beastAC", "number", DB.getValue(nodeSPath, "ac"));
			DB.setValue(nodeShapechange, "beastCR", "string", DB.getValue(nodeSPath, "cr"));
			DB.setValue(nodeShapechange, "beastName", "string", DB.getValue(nodeSPath, "name"));
			DB.setValue(nodeShapechange, "beastSize", "string", DB.getValue(nodeSPath, "size"));
			DB.setValue(nodeShapechange, "beastSpeed", "string", DB.getValue(nodeSPath, "speed"));
			DB.setValue(nodeShapechange, "beastToken", "token", DB.getValue(nodeSPath, "token"));

			local nodeBeastAbilities = DB.createChild(nodeShapechange, "beastAbilities")
			for _, vAbility in ipairs(DB.getChildList(nodeSPath, "abilities")) do
				if DB.getPath(vAbility):find("strength") then
					DB.createChild(nodeBeastAbilities, "strength", "number");
					DB.setValue(nodeBeastAbilities, "strength", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("dexterity") then
					DB.createChild(nodeBeastAbilities, "dexterity", "number");
					DB.setValue(nodeBeastAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("constitution") then
					DB.createChild(nodeBeastAbilities, "constitution", "number");
					DB.setValue(nodeBeastAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("intelligence") then
					DB.createChild(nodeBeastAbilities, "intelligence", "number");
					DB.setValue(nodeBeastAbilities, "intelligence", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("wisdom") then
					DB.createChild(nodeBeastAbilities, "wisdom", "number");
					DB.setValue(nodeBeastAbilities, "wisdom", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):find("charisma") then
					DB.createChild(nodeBeastAbilities, "charisma", "number");
					DB.setValue(nodeBeastAbilities, "charisma", "number", DB.getValue(vAbility, "score"));
				end
			end

			local nodeActions = DB.createChild(nodeShapechange, "actions");
			for _, vAction in ipairs(DB.getChildList(nodeSPath, "actions")) do
				local actionNode = DB.createChild(nodeActions, DB.getValue(vAction, "name"));
				DB.createChild(actionNode, "name", "string");
				DB.createChild(actionNode, "desc", "string");
				DB.setValue(actionNode, "name", "string", DB.getValue(vAction, "name"));
				DB.setValue(actionNode, "desc", "string", DB.getValue(vAction, "desc"));
			end

			local nodeTraitList = DB.createChild(nodeShapechange, "traits");
			for _, vTrait in ipairs(DB.getChildList(nodeSPath, "traits")) do
				local traitNode = DB.createChild(nodeTraitList, DB.getValue(vTrait, "name"));
				DB.createChild(traitNode, "name", "string");
				DB.createChild(traitNode, "desc", "string");
				DB.setValue(traitNode, "name", "string", DB.getValue(vTrait, "name"));
				DB.setValue(traitNode, "desc", "string", DB.getValue(vTrait, "desc"));
			end
			
			bShapechanged = false;
			return nodeShapechange;
		end
	end
end
function loadDisguise(sShapechangeName, userID)
	if string.find(sShapechangeName, " ") then
		sShapechangeName = sShapechangeName:gsub(" ", "");
	end
	
	local nodeShapechangeDB = DB.findNode("shapechange_forms");
	for _, vShapechange in ipairs(DB.getChildList(nodeShapechangeDB)) do
		local sPath = DB.getValue(vShapechange, "noderef");
		if sPath:find(sShapechangeName:lower()) then
			local shapechange = DB.getChild(userID,".shapechange");
			if shapechange ~= nil then
				DB.deleteNode(shapechange);
			end

			local nodeShapechange = DB.createChild(userID, "shapechange");
			
			DB.createChild(nodeShapechange, "beastHP", "number");
			DB.createChild(nodeShapechange, "beastAC", "number");
			DB.createChild(nodeShapechange, "beastCR", "string");
			DB.createChild(nodeShapechange, "beastName", "string");
			DB.createChild(nodeShapechange, "beastSize", "string");
			DB.createChild(nodeShapechange, "beastSpeed", "string");
			DB.createChild(nodeShapechange, "beastToken", "token");
			
			DB.setValue(nodeShapechange, "beastHP", "number", DB.getValue(userID, "hp.total"));
			DB.setValue(nodeShapechange, "beastAC", "number", DB.getValue(userID, "defenses.ac.total"));
			DB.setValue(nodeShapechange, "beastCR", "string", DB.getValue(vShapechange, "beastCR"));
			DB.setValue(nodeShapechange, "beastName", "string", DB.getValue(userID, "name"));
			DB.setValue(nodeShapechange, "beastSize", "string", DB.getValue(userID, "size"));
			DB.setValue(nodeShapechange, "beastSpeed", "string", DB.getValue(vShapechange, "speed"));
			DB.setValue(nodeShapechange, "beastToken", "token", DB.getValue(DB.findNode(sPath), "token"));
			
			local nodeBeastAbilities = DB.createChild(nodeShapechange, "beastAbilities")
			local nodeCharAbilities = DB.getChild(userID, "abilities");
			for _, vAbility in ipairs(DB.getChildList(nodeCharAbilities)) do
				if DB.getPath(vAbility):match("strength") then
					DB.createChild(nodeBeastAbilities, "strength", "number");
					DB.setValue(nodeBeastAbilities, "strength", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):match("dexterity") then
					DB.createChild(nodeBeastAbilities, "dexterity", "number");
					DB.setValue(nodeBeastAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):match("constitution") then
					DB.createChild(nodeBeastAbilities, "constitution", "number");
					DB.setValue(nodeBeastAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):match("intelligence") then
					DB.createChild(nodeBeastAbilities, "intelligence", "number");
					DB.setValue(nodeBeastAbilities, "intelligence", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):match("wisdom") then
					DB.createChild(nodeBeastAbilities, "wisdom", "number");
					DB.setValue(nodeBeastAbilities, "wisdom", "number", DB.getValue(vAbility, "score"));
				end
				if DB.getPath(vAbility):match("charisma") then
					DB.createChild(nodeBeastAbilities, "charisma", "number");
					DB.setValue(nodeBeastAbilities, "charisma", "number", DB.getValue(vAbility, "score"));
				end
			end
			
			bShapechanged = true;
			return nodeShapechange;
		end
	end
end

--Player Filter Selection from Modules
function OOBFilterDB(vShapechange)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_FILTER_DB;
	msgOOB.form = vShapechange;
	Comm.deliverOOBMessage(msgOOB);
end
--Process form change regardless of type
function OOBProcess(userID)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_PROCESS_CHANGE;
	msgOOB.char = DB.getPath(userID);
	Comm.deliverOOBMessage(msgOOB);
end
--Restore Player Data
function OOBRestore(userID)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_RESTORE_CHANGE;
	msgOOB.char = DB.getPath(userID);
	Comm.deliverOOBMessage(msgOOB);
end
--Restore Player Data by hp 0
function OOBForcedRestore(nodeTarget)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_RESTORE_CHANGE;
	local userID = string.gsub(DB.getPath(nodeTarget), "charsheet.", "");
	msgOOB.char = userID;
	Comm.deliverOOBMessage(msgOOB);
end
--Host Process change on character regardless of type
function hostProcess(nodeChar)
	local nodeRevert = DB.getChild(nodeChar, "revert_form");
	if nodeRevert then
		return;
	end

	nodeRevert = DB.createChild(nodeChar, "revert_form");
	
	DB.createChild(nodeRevert, "originalTotalHP", "number");
	DB.createChild(nodeRevert, "originalWounds", "number");
	DB.createChild(nodeRevert, "originalAC", "number");
	DB.createChild(nodeRevert, "originalArmor", "number");
	DB.createChild(nodeRevert, "originalShield", "number");
	DB.createChild(nodeRevert, "originalSize", "string");
	DB.createChild(nodeRevert, "originalToken", "token");
	
	DB.setValue(nodeRevert, "originalTotalHP", "number", DB.getValue(DB.getChild(nodeChar, "hp"), "total"));
	DB.setValue(nodeRevert, "originalWounds", "number", DB.getValue(DB.getChild(nodeChar, "hp"), "wounds"));
	DB.setValue(nodeRevert, "originalAC", "number", DB.getValue(DB.getChild(nodeChar, "defenses.ac"), "total"));
	DB.setValue(nodeRevert, "originalArmor", "number", DB.getValue(DB.getChild(nodeChar, "defenses.ac"), "armor"));
	DB.setValue(nodeRevert, "originalShield", "number", DB.getValue(DB.getChild(nodeChar, "defenses.ac"), "shield", 0));
	DB.setValue(nodeRevert, "originalSize", "string", DB.getValue(nodeChar, "size"));
	DB.setValue(nodeRevert, "originalToken", "token", DB.getValue(nodeChar, "token"));
	
	local nodeAbilities = DB.createChild(nodeRevert, "originalAbilities");
	for _, vAbility in ipairs(DB.getChildList(nodeChar, "abilities")) do
		if DB.getPath(vAbility):match("strength") then
			DB.createChild(nodeAbilities, "strength", "number");
			DB.setValue(nodeAbilities, "strength", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("dexterity") then
			DB.createChild(nodeAbilities, "dexterity", "number");
			DB.setValue(nodeAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("constitution") then
			DB.createChild(nodeAbilities, "constitution", "number");
			DB.setValue(nodeAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("intelligence") then
			DB.createChild(nodeAbilities, "intelligence", "number");
			DB.setValue(nodeAbilities, "intelligence", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("wisdom") then
			DB.createChild(nodeAbilities, "wisdom", "number");
			DB.setValue(nodeAbilities, "wisdom", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("charisma") then
			DB.createChild(nodeAbilities, "charisma", "number");
			DB.setValue(nodeAbilities, "charisma", "number", DB.getValue(vAbility, "score"));
		end
	end
	
	applyFormChange(nodeChar);
end
--Host restore Player Data
function hostRestore(nodeChar)
	local nodeRevert = DB.getChild(nodeChar, "revert_form");
	if nodeRevert == nil then
		return;
	end

	local nodeWeaponList = DB.getChild(nodeChar, "weaponlist");
	local nodeCharTraitList = DB.getChild(nodeChar, "traitlist");
	local nodeCharPowerList = DB.getChild(nodeChar, "powers");
	local nodeFeatureList = DB.getChild(nodeChar, "featurelist");
	local nodePowerList = DB.getChild(nodeChar, "shapechange.powers");
	local nodeBeastTraits = DB.getChild(nodeChar, "shapechange.traits");
	local nodeBeastActions = DB.getChild(nodeChar, "shapechange.actions");
	
	DB.setValue(nodeChar, "hp.total", "number", DB.getValue(nodeRevert, "originalTotalHP"));
	DB.setValue(nodeChar, "hp.wounds", "number", DB.getValue(nodeRevert, "originalWounds"));
	DB.setValue(nodeChar, "defenses.ac.total", "number", DB.getValue(nodeRevert, "originalAC"));
	DB.setValue(nodeChar, "defenses.ac.armor", "number", DB.getValue(nodeRevert, "originalArmor"));
	DB.setValue(nodeChar, "defenses.ac.shield", "number", DB.getValue(nodeRevert, "originalShield"));
	DB.setValue(nodeChar, "size", "string", DB.getValue(nodeRevert, "originalSize"));
	DB.setValue(nodeChar, "token", "token", DB.getValue(nodeRevert, "originalToken"));

	local nodeAbilities = DB.getChild(nodeChar, "abilities");
	for _, vAbility in ipairs(DB.getChildList(nodeRevert, "originalAbilities")) do
		if DB.getPath(vAbility):match("strength") then
			DB.setValue(nodeAbilities, "strength.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("dexterity") then
			DB.setValue(nodeAbilities, "dexterity.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("constitution") then
			DB.setValue(nodeAbilities, "constitution.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("intelligence") then
			DB.setValue(nodeAbilities, "intelligence.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("wisdom") then
			DB.setValue(nodeAbilities, "wisdom.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("charisma") then
			DB.setValue(nodeAbilities, "charisma.score", "number", DB.getValue(vAbility));
		end
	end
	
	local nodeInventoryList = DB.getChild(nodeChar, "inventorylist");
	for _, vItem in ipairs(DB.getChildList(nodeInventoryList)) do
		if vItem ~= nil then
			local sItemType = DB.getValue(vItem, "type");
			for _, vEquippedItem in ipairs(tEquippedList) do
				if vEquippedItem ~= nil and vItem ~= nil  then
					if DB.getPath(vItem) == DB.getPath(vEquippedItem) then
						DB.setValue(vItem, "carried", "number", 2);
					end
				end
			end
		end
	end
	
	for _, vBeastAction in ipairs(DB.getChildList(nodeBeastActions)) do
		for _, vActionEntry in ipairs(DB.getChildList(nodeWeaponList)) do
			if vActionEntry ~= nil and vBeastAction ~= nil  then
				if DB.getValue(vActionEntry, "name"):find(DB.getValue(vBeastAction, "name")) or DB.getValue(vActionEntry, "name"):find("Recharge") or DB.getValue(vActionEntry, "name"):find("Hybrid") then
					DB.deleteNode(vActionEntry);
				end
			end
		end
	end
	
	for _, vBeastAction in ipairs(DB.getChildList(nodeBeastActions)) do
		for _, vFeatureEntry in ipairs(DB.getChildList(nodeFeatureList)) do
			if vFeatureEntry ~= nil and vBeastAction ~= nil  then
				if DB.getValue(vFeatureEntry, "name"):find(DB.getValue(vBeastAction, "name")) or DB.getValue(vFeatureEntry, "name"):find("Breath") or DB.getValue(vFeatureEntry, "name"):find("Recharge") or DB.getValue(vFeatureEntry, "name"):find("Hybrid") then
					DB.deleteNode(vFeatureEntry);
				end
			end
		end
	end
	
	for _, vBeastTrait in ipairs(DB.getChildList(nodeBeastTraits)) do
		for _, vTraitEntry in ipairs(DB.getChildList(nodeCharTraitList)) do
			if vTraitEntry ~= nil and vBeastTrait ~= nil then
				if DB.getValue(vTraitEntry, "name"):find(DB.getValue(vBeastTrait, "name")) or DB.getValue(vTraitEntry, "name"):find("Legendary Resistance") or DB.getValue(vTraitEntry, "name"):find("Hybrid") then
					DB.deleteNode(vTraitEntry);
				end
			end
		end
	end
	
	local tPowersToRemove = {};
	for _, vCharPower in ipairs(DB.getChildList(nodeCharPowerList)) do
		for _, vBeastPower in ipairs(DB.getChildList(nodeChar, "shapechange.actions")) do
			if DB.getValue(vCharPower, "name") == DB.getValue(vBeastPower, "name") then
				table.insert(tPowersToRemove, vCharPower);
			end
		end
	end
	
	for _, nodePowerToDelete in ipairs(tPowersToRemove) do
		DB.deleteNode(nodePowerToDelete);
	end
		
	local nodeCT = CombatManager.getCTFromNode(nodeChar);
	if nodeCT ~= nil then
		DB.setValue(nodeCT, "token", "token", DB.getValue(nodeRevert, "originalToken"));
		DB.setValue(nodeCT, "space", "number", 5);
		CombatManager.replaceCombatantToken(nodeCT, nil);
	end
	DB.deleteNode(nodeRevert);
	characterShapechanged = false;
end
--Create Data Cache for reverting form later
function storePlayerData(msgOOB)
	local nodeChar = DB.findNode(msgOOB.char);
	local nodeRevert = DB.getChild(nodeChar, "revert_form");
	if nodeRevert then
		return;
	end

	nodeRevert = DB.createChild(nodeChar, "revert_form");
	
	DB.createChild(nodeRevert, "originalTotalHP", "number");
	DB.createChild(nodeRevert, "originalWounds", "number");
	DB.createChild(nodeRevert, "originalAC", "number");
	DB.createChild(nodeRevert, "originalArmor", "number");
	DB.createChild(nodeRevert, "originalShield", "number");
	DB.createChild(nodeRevert, "originalSize", "string");
	DB.createChild(nodeRevert, "originalToken", "token");
	
	DB.setValue(nodeRevert, "originalTotalHP", "number", DB.getValue(DB.getChild(nodeChar, "hp"), "total"));
	DB.setValue(nodeRevert, "originalWounds", "number", DB.getValue(DB.getChild(nodeChar, "hp"), "wounds"));
	DB.setValue(nodeRevert, "originalAC", "number", DB.getValue(DB.getChild(nodeChar, "defenses.ac"), "total"));
	DB.setValue(nodeRevert, "originalArmor", "number", DB.getValue(DB.getChild(nodeChar, "defenses.ac"), "armor"));
	DB.setValue(nodeRevert, "originalShield", "number", DB.getValue(DB.getChild(nodeChar, "defenses.ac"), "shield", 0));
	DB.setValue(nodeRevert, "originalSize", "string", DB.getValue(nodeChar, "size"));
	DB.setValue(nodeRevert, "originalToken", "token", DB.getValue(nodeChar, "token"));
	
	local nodeAbilities = DB.createChild(nodeRevert, "originalAbilities");
	for _, vAbility in ipairs(DB.getChildList(nodeChar, "abilities")) do
		if DB.getPath(vAbility):match("strength") then
			DB.createChild(nodeAbilities, "strength", "number");
			DB.setValue(nodeAbilities, "strength", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("dexterity") then
			DB.createChild(nodeAbilities, "dexterity", "number");
			DB.setValue(nodeAbilities, "dexterity", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("constitution") then
			DB.createChild(nodeAbilities, "constitution", "number");
			DB.setValue(nodeAbilities, "constitution", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("intelligence") then
			DB.createChild(nodeAbilities, "intelligence", "number");
			DB.setValue(nodeAbilities, "intelligence", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("wisdom") then
			DB.createChild(nodeAbilities, "wisdom", "number");
			DB.setValue(nodeAbilities, "wisdom", "number", DB.getValue(vAbility, "score"));
		end
		if DB.getPath(vAbility):match("charisma") then
			DB.createChild(nodeAbilities, "charisma", "number");
			DB.setValue(nodeAbilities, "charisma", "number", DB.getValue(vAbility, "score"));
		end
	end
	
	applyFormChange(nodeChar);
end
--Apply Shapechange to Character
function applyFormChange(nodeChar)
	local nodeShapechange = DB.getChild(nodeChar, "shapechange");
	if nodeShapechange == nil then
		return;
	end

	DB.setValue(nodeChar, "hp.total", "number", DB.getValue(nodeShapechange, "beastHP"));
	DB.setValue(nodeChar, "hp.wounds", "number", 0);
	DB.setValue(nodeChar, "size", "string", DB.getValue(nodeShapechange, "size"));
	DB.setValue(nodeChar, "token", "token", DB.getValue(nodeShapechange, "token"));
	local nACDifference = DB.getValue(nodeShapechange, "beastAC") - 10 - math.floor((DB.getValue(nodeShapechange, "beastAbilities.dexterity") - 10) / 2);
	if nACDifference then
		DB.setValue(nodeChar, "defenses.ac.armor", "number", nACDifference);
	end
	DB.setValue(nodeChar, "defenses.ac.shield", "number", 0);
	
	local nodeAbilities = DB.getChild(nodeChar, "abilities");
	for _, vAbility in ipairs(DB.getChildList(nodeShapechange, "beastAbilities")) do
		if DB.getPath(vAbility):match("strength") then
			DB.setValue(nodeAbilities, "strength.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("dexterity") then
			DB.setValue(nodeAbilities, "dexterity.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("constitution") then
			DB.setValue(nodeAbilities, "constitution.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("intelligence") then
			DB.setValue(nodeAbilities, "intelligence.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("wisdom") then
			DB.setValue(nodeAbilities, "wisdom.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("charisma") then
			DB.setValue(nodeAbilities, "charisma.score", "number", DB.getValue(vAbility));
		end
	end

	local nodeInventoryList = DB.getChild(nodeChar, "inventorylist");
	for _, vItem in ipairs(DB.getChildList(nodeInventoryList)) do
		local sItemType = DB.getValue(vItem, "type");
		if vItem ~= nil then
			if DB.getChild(vItem, "type") then
				if (string.match(sItemType, "Weapon") or string.match(sItemType, "Armor")) and DB.getValue(vItem, "carried") == 2 then
					DB.setValue(vItem, "carried", "number", 1);
					table.insert(tEquippedList, vItem);
				end
			end
		end
	end
	
	if bShapechanged ~= true then
		applyTraitsActions(nodeChar);
		characterShapechanged = true;
	else
		bShapechanged = false;
	end
	
	local sSize = DB.getValue(nodeShapechange, "beastSize"):lower();
	local nodeCT = CombatManager.getCTFromNode(nodeChar);
	if nodeCT ~= nil then
		DB.setValue(nodeCT, "token", "token", DB.getValue(nodeShapechange, "beastToken"));
		if sSize:match("large") then
			DB.setValue(nodeCT, "space", "number", 10);
		end
		if sSize:match("huge") then
			DB.setValue(nodeCT, "space", "number", 15);
		end
		if sSize:match("gargantuan") then
			DB.setValue(nodeCT, "space", "number", 20);
		end
		CombatManager.replaceCombatantToken(nodeCT, nil);
	end
end

--Apply beast traits and actions to character sheet
function applyTraitsActions(nodeChar)
	local nodeCharTraitList = DB.getChild(nodeChar, "traitlist");
	local nodeCharPowerList = DB.getChild(nodeChar, "powers");
	local nodeWeaponList = DB.getChild(nodeChar, "weaponlist");
	local nodeFeatureList = DB.getChild(nodeChar, "featurelist");
	local nodePowerList = DB.createChild(DB.getChild(nodeChar, "shapechange"), "powers");
	local nodeBeastTraits = DB.getChild(nodeChar, "shapechange.traits");
	local nodeBeastActions = DB.getChild(nodeChar, "shapechange.actions");

	local tWeaponsContainsChecks = {};
	local tTraitsContainsChecks = {};
	local tFeaturesContainsCheck = {};
	local tFeaturesToAdd = {};

	for _, vBeastAction in ipairs(DB.getChildList(nodeBeastActions)) do
		for _, vActionEntry in ipairs(DB.getChildList(nodeWeaponList)) do
			if not string.match(DB.getPath(vBeastAction), DB.getValue(vActionEntry, "name")) then
				table.insert(tWeaponsContainsChecks, false);
			else
				table.insert(tWeaponsContainsChecks, true);
			end
		end
		for index, vBool in ipairs(tWeaponsContainsChecks) do
			if vBool == true then
				break;
			end
			if index == #tWeaponsContainsChecks then
				local sActionDesc = DB.getValue(vBeastAction, "desc");
				local sAttackType = string.match(sActionDesc, "(%w+) Weapon Attack:");
				local sAttackToHit = string.match(sActionDesc, "([%+%-]?%d+) to hit");
				if sAttackType then
					local nodeAction;
					local nodeDamageList;
					local nodeAltAction = nil;
					local nodeAltDamageList = nil;
					local prevEnd = 0;
					local substring;
					local sTotalDamage, sDice, sBonus, sDamageType;
					local sParenthesis;
					for sMatch in string.gmatch(sActionDesc, "damage") do
						if substring ~= nil then
							sActionDesc = sActionDesc:sub(prevEnd);
							local sControl = sActionDesc:lower();
							local first, second = sControl:find("or");
							if first == nil or second == nil then
								first, second = sControl:find("Or");
							end
							if first ~= nil and second ~= nil then
								if first < 10 or second < 10 then
									nodeAltAction = DB.createChild(nodeWeaponList);
									local sSecondAttackType = string.match(sActionDesc, "(%w+) Weapon Attack:");
									if sSecondAttackType ~= nil then
										sAttackType = sSecondAttackType;
									end
									nodeAltDamageList = DB.createChild(nodeAltAction, "damagelist");
								else
									nodeDamageList = DB.createChild(nodeAction, "damagelist");
								end
							end
						else
							nodeAction = DB.createChild(nodeWeaponList);
							nodeDamageList = DB.createChild(nodeAction, "damagelist");
						end
						local _, endPos = string.find(sActionDesc, sMatch);
						substring = string.sub(sActionDesc, 0, endPos);
						prevEnd = endPos;
						sTotalDamage, sDice, sBonus, sDamageType = substring:match("(%((%d*d%d+)%s*([%+%-]?%s*%d+)%))%s*(%w+) damage");
						if sTotalDamage then
							sBonus = sBonus:match("[+-]%s*(%d+)");
							if sDice:match("d1$") then
								sDice = sDice .. "0";
							end
						else
							sParenthesis, sDamageType = string.match(substring, "(%b()) (%a+) damage");
							if sParenthesis ~= nil then
								sParenthesis = sParenthesis:gsub("%(", "");
								sParenthesis = sParenthesis:gsub("%)", "");
								sDice = sParenthesis:match("(%d*d%d*)");
								sBonus = sParenthesis:match("+%s*(%d+)");
								sTotalDamage = sParenthesis;
							else
								sTotalDamage, sDamageType = string.match(substring, "(%d+) (%a+) damage");
								sBonus = sTotalDamage;
							end
						end
						local nBonus;
						local dDice;
						local nToHit;
						if sDice ~= nil then
							dDice = DiceManager.convertStringToDice(sDice);
							if sTotalDamage:match("-") and sBonus ~= nil then
								nBonus = tonumber("-" .. sBonus);
							elseif sBonus ~= nil then
								nBonus = tonumber(sBonus);
							end
						else
							if sTotalDamage:match("-") and sBonus ~= nil then
								nBonus = tonumber("-" .. sBonus);
							else
								nBonus = tonumber(sBonus);
							end
						end
						
						if sAttackToHit then
							local sNegPos, sNumber = string.match(sAttackToHit, "([%+%-])(%d+)");
							if sNegPos then
								if sNegPos:match("-") then
									nToHit = tonumber(sNegPos .. sNumber);
								else
									nToHit = tonumber(sNumber);
								end
							else
								nToHit = tonumber(sNumber);
							end
						end
						
						if nodeAltAction == nil then
							DB.createChild(nodeAction, "name", "string");
							local nodeDamageListEntry = DB.createChild(nodeDamageList);
							DB.setValue(nodeAction, "name", "string", DB.getValue(DB.getChild(nodeChar, "shapechange"), "beastName") .. ": " .. DB.getValue(vBeastAction, "name"));
							DB.setValue(nodeAction, "attackstat", "string", "charisma");
							DB.setValue(nodeAction, "prof", "number", 0);
						
							if string.lower(sAttackType):match("melee") then
								DB.setValue(nodeAction, "type", "number", 0);
							elseif string.lower(sAttackType):match("ranged") then
								DB.setValue(nodeAction, "type", "number", 1);
							elseif string.lower(sAttackType):match("thrown") then
								DB.setValue(nodeAction, "type", "number", 2);
							end
							
							if nBonus ~= nil then
								DB.setValue(nodeDamageListEntry, "bonus", "number", nBonus);
							end
							if dDice ~= nil then
								DB.setValue(nodeDamageListEntry, "dice", "dice", dDice);
							end
							if sDamageType ~= nil then
								DB.setValue(nodeDamageListEntry, "type", "string", sDamageType .. " damage");
							end
							if nToHit ~= nil then
								local nChaMod = math.floor((DB.getValue(nodeChar, "abilities.charisma.score") - 10) / 2);
								local nProfBonus = DB.getValue(nodeChar, "profbonus");
								if nToHit >= 0 then
									DB.setValue(nodeAction, "attackbonus", "number", nToHit - nChaMod - nProfBonus);
								end
							end
						else
							DB.createChild(nodeAltAction, "name", "string");
							local nodeDamageListEntry = DB.createChild(nodeAltDamageList);
							DB.setValue(nodeAltAction, "name", "string", DB.getValue(DB.getChild(nodeChar, "shapechange"), "beastName") .. ": " .. DB.getValue(vBeastAction, "name") .. " - Alternate");
							DB.setValue(nodeAltAction, "attackstat", "string", "charisma");
							DB.setValue(nodeAltAction, "prof", "number", 0);
						
							if string.lower(sAttackType):match("melee") then
								DB.setValue(nodeAltAction, "type", "number", 0);
							elseif string.lower(sAttackType):match("ranged") then
								DB.setValue(nodeAltAction, "type", "number", 1);
							elseif string.lower(sAttackType):match("thrown") then
								DB.setValue(nodeAltAction, "type", "number", 2);
							end
							
							if nBonus ~= nil then
								DB.setValue(nodeDamageListEntry, "bonus", "number", nBonus);
							end
							if dDice ~= nil then
								DB.setValue(nodeDamageListEntry, "dice", "dice", dDice);
							end
							if sDamageType ~= nil then
								DB.setValue(nodeDamageListEntry, "type", "string", sDamageType .. " damage");
							end
							if nToHit ~= nil then
								local nChaMod = math.floor((DB.getValue(nodeChar, "abilities.charisma.score") - 10) / 2);
								local nProfBonus = DB.getValue(nodeChar, "profbonus");
								if nToHit >= 0 then
									DB.setValue(nodeAltAction, "attackbonus", "number", nToHit - nChaMod - nProfBonus);
								end
							end

						end
					end
				else
					table.insert(tFeaturesToAdd, vBeastAction);
				end
			
			end
		end
		tWeaponsContainsChecks = {};
	end

	for _, vFeature in ipairs(tFeaturesToAdd) do
		local sFeatureDesc = DB.getValue(vFeature, "desc");	
		local sFeatureName = DB.getValue(vFeature, "name");
		local sDC, sStat = string.match(sFeatureDesc, "DC (%d+) (%w+) saving throw");
		local bHalfOnSuccess = string.match(sFeatureDesc, "half as much");
		if sDC and sStat then
			local nDC = tonumber(sDC);
			local nodePower = DB.createChild(nodeCharPowerList, sFeatureName);
			local nodePowerActions = DB.createChild(nodePower, "actions");
			local nodeAction = DB.createChild(nodePowerActions);
			
			DB.createChild(nodeAction, "onmissdamage", "string");
			DB.createChild(nodeAction, "order", "number");
			DB.createChild(nodeAction, "savetype", "string");
			DB.createChild(nodeAction, "type", "string");
			DB.createChild(nodeAction, "name", "string");
			DB.createChild(nodeAction, "savedcbase", "string");
			DB.createChild(nodeAction, "savedcmod", "number");
			--DB.createChild(nodeAction, "grouping", "string");
			
			DB.setValue(nodeAction, "order", "number", 1);
			DB.setValue(nodeAction, "savedcbase", "string", "fixed");
			DB.setValue(nodeAction, "savetype", "string", sStat:lower());
			DB.setValue(nodeAction, "savedcmod", "number", tonumber(sDC));
			DB.setValue(nodeAction, "type", "string", "cast");
			DB.setValue(nodePower, "name", "string", sFeatureName);
			--DB.setValue(nodePower, "grouping", "string", DB.getValue(DB.getChild(nodeChar, "shapechange"), "beastName") .. " Powers");
			
			if bHalfOnSuccess then
				DB.setValue(nodeAction, "onmissdamage", "string", "half");
				local nodeAction2 = DB.createChild(nodePowerActions);
				DB.createChild(nodeAction2, "order", "number");
				DB.createChild(nodeAction2, "type", "string");
				DB.setValue(nodeAction2, "order", "number", 2);
				DB.setValue(nodeAction2, "type", "string", "damage");
				
				local nodeDamageList = DB.createChild(nodeAction2, "damagelist");
				local sTotalDamage, sDice, sBonus, sDamageType = sFeatureDesc:match("(%((%d*d%d+)%s*([%+%-]?%s*%d+)%))%s*(%w+) damage");

				if sTotalDamage then
					sBonus = sBonus:match("[+-]%s*(%d+)");
					if sDice:match("d1$") then
						sDice = sDice .. "0";
					end
				else
					sParenthesis, sDamageType = string.match(sFeatureDesc, "(%b()) (%a+) damage");
					if sParenthesis ~= nil then
						sParenthesis = sParenthesis:gsub("%(", "");
						sParenthesis = sParenthesis:gsub("%)", "");
						sDice = sParenthesis:match("(%d*d%d*)");
						sBonus = sParenthesis:match("+%s*(%d+)");
						sTotalDamage = sParenthesis;
					else
						sTotalDamage, sDamageType = string.match(sFeatureDesc, "(%d+) (%a+) damage");
						sBonus = sTotalDamage;
					end
				end

				local nBonus;
				local dDice;

				if sDice ~= nil then
					dDice = DiceManager.convertStringToDice(sDice);
				end
				
				local nodeDamageListEntry = DB.createChild(nodeDamageList);
				DB.createChild(nodeDamageListEntry, "bonus", "number");
				DB.createChild(nodeDamageListEntry, "dice", "dice");
				DB.createChild(nodeDamageListEntry, "type", "string");
				DB.setValue(nodeDamageListEntry, "bonus", "number", nBonus);
				DB.setValue(nodeDamageListEntry, "dice", "dice", dDice);
				DB.setValue(nodeDamageListEntry, "type", "string", sDamageType);
				
				DB.createChild(nodePower, "group", "string");
				DB.createChild(nodePower, "name", "string");
				DB.createChild(nodePower, "level", "number");
				DB.createChild(nodePower, "locked", "number");
				DB.createChild(nodePower, "text", "formattedtext");
			
				DB.setValue(nodePower, "name", "string", sFeatureName);
				DB.setValue(nodePower, "text", "formattedtext", sFeatureDesc);
			end

			for _, vEffect in ipairs(tListOfEffects) do
				if string.match(sFeatureDesc:lower(), vEffect:lower()) then
					local nodeActionEffect = DB.createChild(nodePowerActions);
					
					DB.createChild(nodeActionEffect, "order", "number");
					DB.createChild(nodeActionEffect, "type", "string");
					DB.createChild(nodeActionEffect, "name", "string");
					DB.createChild(nodeActionEffect, "label", "string");
					
					DB.setValue(nodeActionEffect, "order", "number", 2);
					DB.setValue(nodeActionEffect, "type", "string", "effect");
					DB.setValue(nodeActionEffect, "name", "string", sFeatureName);
					DB.setValue(nodeActionEffect, "label", "string", vEffect);
				end
			end
		else
			local nodeFeature = DB.createChild(nodeFeatureList);
			DB.createChild(nodeFeature, "name", "string");
			DB.createChild(nodeFeature, "text", "formattedtext");
		
			DB.setValue(nodeFeature, "name", "string", DB.getValue(DB.getChild(nodeChar, "shapechange"), "beastName") .. ": " .. sFeatureName);
			DB.setValue(nodeFeature, "text", "formattedtext", sFeatureDesc);
		end
	end
	tFeaturesContainsChecks = {};

	for _, vBeastTrait in ipairs(DB.getChildList(nodeBeastTraits)) do
		for _, vTraitEntry in ipairs(DB.getChildList(nodeCharTraitList)) do
			if not string.match(DB.getPath(vBeastTrait), DB.getValue(vTraitEntry, "name")) then
				table.insert(tTraitsContainsChecks, false);
			else
				table.insert(tTraitsContainsChecks, true);
			end
		end
		
		for index, vBool in ipairs(tTraitsContainsChecks) do
			if vBool == true then
				break;
			end
			if index == #tTraitsContainsChecks then
				local nodeTrait = DB.createChild(nodeCharTraitList);
				DB.createChild(nodeTrait, "name", "string");
				DB.setValue(nodeTrait, "name", "string", DB.getValue(DB.getChild(nodeChar, "shapechange"), "beastName") .. ": " .. DB.getValue(vBeastTrait, "name") .. " - " .. DB.getValue(vBeastTrait, "desc"));
			end
		end
		
		tTraitsContainsChecks = {};
	end
end

--Restore Player Data
function restorePlayerData(msgOOB)
	local nodeChar = DB.findNode(msgOOB.char);
	local nodeRevert = DB.getChild(nodeChar, "revert_form");
	local nodeWeaponList = DB.getChild(nodeChar, "weaponlist");
	local nodeCharTraitList = DB.getChild(nodeChar, "traitlist");
	local nodeCharPowerList = DB.getChild(nodeChar, "powers");
	local nodeFeatureList = DB.getChild(nodeChar, "featurelist");
	local nodePowerList = DB.getChild(nodeChar, "shapechange.powers");
	local nodeBeastTraits = DB.getChild(nodeChar, "shapechange.traits");
	local nodeBeastActions = DB.getChild(nodeChar, "shapechange.actions");

	if nodeRevert == nil then
		return;
	end
	
	DB.setValue(nodeChar, "hp.total", "number", DB.getValue(nodeRevert, "originalTotalHP"));
	DB.setValue(nodeChar, "hp.wounds", "number", DB.getValue(nodeRevert, "originalWounds"));
	DB.setValue(nodeChar, "defenses.ac.total", "number", DB.getValue(nodeRevert, "originalAC"));
	DB.setValue(nodeChar, "defenses.ac.armor", "number", DB.getValue(nodeRevert, "originalArmor"));
	DB.setValue(nodeChar, "defenses.ac.shield", "number", DB.getValue(nodeRevert, "originalShield"));
	DB.setValue(nodeChar, "size", "string", DB.getValue(nodeRevert, "originalSize"));
	DB.setValue(nodeChar, "token", "token", DB.getValue(nodeRevert, "originalToken"));

	local nodeAbilities = DB.getChild(nodeChar, "abilities");
	for _, vAbility in ipairs(DB.getChildList(nodeRevert, "originalAbilities")) do
		if DB.getPath(vAbility):match("strength") then
			DB.setValue(nodeAbilities, "strength.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("dexterity") then
			DB.setValue(nodeAbilities, "dexterity.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("constitution") then
			DB.setValue(nodeAbilities, "constitution.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("intelligence") then
			DB.setValue(nodeAbilities, "intelligence.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("wisdom") then
			DB.setValue(nodeAbilities, "wisdom.score", "number", DB.getValue(vAbility));
		end
		if DB.getPath(vAbility):match("charisma") then
			DB.setValue(nodeAbilities, "charisma.score", "number", DB.getValue(vAbility));
		end
	end
	
	local nodeInventoryList = DB.getChild(nodeChar, "inventorylist");
	for _, vItem in ipairs(DB.getChildList(nodeInventoryList)) do
		if vItem ~= nil then
			local sItemType = DB.getValue(vItem, "type");
			for _, vEquippedItem in ipairs(tEquippedList) do
				if vEquippedItem ~= nil then
					if DB.getPath(vItem) == DB.getPath(vEquippedItem) then
						DB.setValue(vItem, "carried", "number", 2);
					end
				end
			end
		end
	end
	
	for _, vBeastAction in ipairs(DB.getChildList(nodeBeastActions)) do
		for _, vActionEntry in ipairs(DB.getChildList(nodeWeaponList)) do
			if vActionEntry ~= nil then
				if DB.getValue(vActionEntry, "name"):find(DB.getValue(vBeastAction, "name")) or DB.getValue(vActionEntry, "name"):find("Recharge") or DB.getValue(vActionEntry, "name"):find("Hybrid") then
					DB.deleteNode(vActionEntry);
				end
			end
		end
	end
	
	for _, vBeastAction in ipairs(DB.getChildList(nodeBeastActions)) do
		for _, vFeatureEntry in ipairs(DB.getChildList(nodeFeatureList)) do
			if vFeatureEntry ~= nil then
				if DB.getValue(vFeatureEntry, "name"):find(DB.getValue(vBeastAction, "name")) or DB.getValue(vFeatureEntry, "name"):find("Breath") or DB.getValue(vFeatureEntry, "name"):find("Recharge") or DB.getValue(vFeatureEntry, "name"):find("Hybrid") then
					DB.deleteNode(vFeatureEntry);
				end
			end
		end
	end
	
	for _, vBeastTrait in ipairs(DB.getChildList(nodeBeastTraits)) do
		for _, vTraitEntry in ipairs(DB.getChildList(nodeCharTraitList)) do
			if vTraitEntry ~= nil then
				if DB.getValue(vTraitEntry, "name"):find(DB.getValue(vBeastTrait, "name")) or DB.getValue(vTraitEntry, "name"):find("Legendary Resistance") or DB.getValue(vTraitEntry, "name"):find("Hybrid") then
					DB.deleteNode(vTraitEntry);
				end
			end
		end
	end
	
	local tPowersToRemove = {};
	for _, vCharPower in ipairs(DB.getChildList(nodeCharPowerList)) do
		for _, vBeastPower in ipairs(DB.getChildList(nodeChar, "shapechange.actions")) do
			if DB.getValue(vCharPower, "name") == DB.getValue(vBeastPower, "name") then
				table.insert(tPowersToRemove, vCharPower);
			end
		end
	end
	
	for _, nodePowerToDelete in ipairs(tPowersToRemove) do
		DB.deleteNode(nodePowerToDelete);
	end
		
	local nodeCT = CombatManager.getCTFromNode(nodeChar);
	if nodeCT ~= nil then
		DB.setValue(nodeCT, "token", "token", DB.getValue(nodeRevert, "originalToken"));
		DB.setValue(nodeCT, "space", "number", 5);
		CombatManager.replaceCombatantToken(nodeCT, nil);
	end
	DB.deleteNode(nodeRevert);
	characterShapechanged = false;
end

--Handles reverting form on wildshape/polymorph reach 0
function myApplyDamage(rSource, rTarget, rRoll)
	local sTargetType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if not sTargetType:match("pc") then 
		fApplyDamage(rSource, rTarget, rRoll);
		return;
	end

	local nOrigHP = DB.getValue(nodeTarget, "hp.total", 0);
	local nCurWounds = DB.getValue(nodeTarget, "hp.wounds", 0);
	local nDamageDealt = rRoll.nTotal;

	fApplyDamage(rSource, rTarget, rRoll);

	local nCombined = (nDamageDealt + nCurWounds);
	if nCombined >= nOrigHP and characterShapechanged then
		nDamageDealt = nCombined - nOrigHP;
		local nodeCT = CombatManager.getCTFromNode(nodeTarget);
		local targetEffectList = DB.getChild(nodeCT, "effects");
		for _, vEffect in ipairs(DB.getChildList(targetEffectList)) do
			if DB.getValue(vEffect, "label"):match("Unconscious") or DB.getValue(vEffect, "label"):match("Prone") then
				DB.deleteNode(vEffect);
			end
		end
		DB.setValue(DB.getChild(nodeTarget, "revert_form"), "originalWounds", "number", (nDamageDealt + DB.getValue(nodeTarget, "revert_form.originalWounds", 0)));
		OOBForcedRestore(nodeTarget);
	end
end
