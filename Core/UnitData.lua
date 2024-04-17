local _, KeyMaster = ...
KeyMaster.UnitData = {}
local UnitData = KeyMaster.UnitData
local PlayerFrameMapping = KeyMaster.PlayerFrameMapping

local unitInformation = {}

-- Function tries to find the unit location (e.g.; party1-4) by their GUID
-- Parameter: unitGUID = Unique Player GUID value.
-- Returns: unitId e.g.; party1, party2, party3, party4
function UnitData:GetUnitId(unitGUID)
    local partyMembers = {"player", "party1", "party2", "party3", "party4"}
    for _,unitId in pairs(partyMembers) do
        if unitGUID == UnitGUID(unitId) then
            return unitId
        end
    end
    return nil
end

local function getUnitRealm(unitGUID)
    local partyMembers = {"player", "party1", "party2", "party3", "party4"}
    for _,unitId in pairs(partyMembers) do
        if unitGUID == UnitGUID(unitId) then
            local name, realm = UnitName(unitId)
            if realm == nil then
                return GetRealmName()
            else
                return realm
            end
        end
    end
    KeyMaster:_ErrorMsg("getUnitRealm", "UnitData", "Cannot find unit for GUID: "..unitGUID)
end

function UnitData:UpdateListCharacter(playerGUID)

    local function getKeyText(cData)
        local keyText
        if cData.keyId > 0 and cData.keyLevel > 0 then
            if not KeyMasterLocals.MAPNAMES[cData.keyId] then
                cData.keyId = 9001 -- unknown keyId
            end
            keyText = "("..tostring(cData.keyLevel)..") "..KeyMasterLocals.MAPNAMES[cData.keyId].abbr
        end
        return keyText
    end

    if not playerGUID then return end

    if not _G["KM_CharacterRow_"..playerGUID] then return end -- nothing to update so exit out.

    local unitData = UnitData:GetUnitDataByGUID(playerGUID)
    if not unitData then return end

    local ratingObj, keyTextObj, keyText
    local keyInfo = {}
    local characterFrame = _G["KM_CharacterRow_"..playerGUID]:GetAttribute("row") or false
    if not characterFrame or not type(characterFrame == "table") then return end
    ratingObj = characterFrame:GetAttribute("overallRating")
    if ratingObj then
        ratingObj:SetText(tostring(UnitData.overallRating))
    end
    keyTextObj = characterFrame:GetAttribute("keyText")
    if unitData.ownedKeyLevel > 0 then
        keyInfo.keyLevel = unitData.ownedKeyLevel
        keyInfo.keyId = unitData.ownedKeyId
        keyText = getKeyText(keyInfo)
    else
        keyText = ""
    end
    if keyTextObj and keyText then
        keyTextObj:SetText(keyText)
    end

    -- only need to do this when the panel is currently visible. Otherwise
    -- the action of showing/hiding the character select frame does this.
    if  _G["KM_CharacterSelectFrame"]  then -- nil check for any unknown states.
        if _G["KM_CharacterSelectFrame"]:IsShown() then
            local PlayerFrame = KeyMaster.PlayerFrame
            PlayerFrame:UpdateCharacterList() -- player frame counterpart - script laoding order.
        end
    end
end

local function setUnitSaveData(unitData)
    -- Save character information to file
    if KeyMaster_C_DB[unitData.GUID] then -- Only updates/saves existing PLAYER characters.
        local LibSerialize = LibStub("LibSerialize")
        local LibDeflate = LibStub("LibDeflate")

        -- pull out/set a couple details for better performance.
        KeyMaster_C_DB[unitData.GUID].rating = unitData.mythicPlusRating
        KeyMaster_C_DB[unitData.GUID].keyId = unitData.ownedKeyId
        KeyMaster_C_DB[unitData.GUID].keyLevel = unitData.ownedKeyLevel
        --KeyMaster_C_DB[unitData.GUID].timestamp = GetServerTime()
        KeyMaster_C_DB[unitData.GUID].vault = nil -- todo: Set Vault Data

        -- Serialize, compress and encode Unit Data for Saved Variables
        local serialized = LibSerialize:Serialize(unitData)
        local compressed = LibDeflate:CompressDeflate(serialized)
        local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
        KeyMaster_C_DB[unitData.GUID].data = encoded
        UnitData:UpdateListCharacter(unitData.GUID)
    end
    -- clean all data every data-update because first run or two can be api-tempermental.
    if unitData.GUID == UnitGUID("PLAYER") then -- make sure it's only the client so not to spam cleanup (more than it already does).
        KeyMaster_C_DB = KeyMaster:CleanCharSavedData(KeyMaster_C_DB)
    end
end

function UnitData:SetUnitData(unitData)
    local unitId = UnitData:GetUnitId(unitData.GUID)
    if unitId == nil then
        KeyMaster:_ErrorMsg("SetUnitData", "UnitData", "UnitId is nil.  Cannot store data for "..unitData.name)
        return
    end
    unitData.unitId = unitId -- set unitId for this client
    
    -- adds backward compatiability from before v0.0.95beta
    if unitData.realm == nil then
        unitData.realm = getUnitRealm(unitData.GUID)
    end
    
    -- STORE DATA IN MEMORY
    unitInformation[unitData.GUID] = unitData

    -- Store/Update Unit Data in Saveved Variables
    setUnitSaveData(unitData)

    KeyMaster:_DebugMsg("SetUnitData", "UnitData", "Stored data for "..unitData.name)
end

function UnitData:SetUnitDataUnitPosition(name, realm, newUnitId)
    local unitData = UnitData:GetUnitDataByName(name, realm)
    if unitData == nil then
        KeyMaster:_ErrorMsg("SetUnitDataUnitPostion", "UnitDat", "Cannot update position for "..name.." because a unit cannot be found by that name.")
        return
    end

    unitInformation[unitData.GUID].unitId = newUnitId
    return unitInformation[unitData.GUID]
end

function UnitData:GetUnitDataByUnitId(unitId)
    for guid, tableData in pairs(unitInformation) do
         if (tableData.unitId == unitId) then
            return unitInformation[guid]
        end
    end

    return nil -- NOT FOUND
end

function UnitData:GetUnitDataByGUID(playerGUID)
    return unitInformation[playerGUID]
end

function UnitData:GetUnitDataByName(name, realm)
    for guid, tableData in pairs(unitInformation) do
        if (tableData.name == name and tableData.realm == realm) then
            return unitInformation[guid]
       end
   end
   KeyMaster:_DebugMsg("GetUnitDataByName", "UnitData", "Cannot find unit by name "..name.." and realm "..realm)
   return nil
end

function UnitData:GetAllUnitData()
    return unitInformation
end

function UnitData:DeleteUnitDataByUnitId(unitId)
    local data = UnitData:GetUnitDataByUnitId(unitId)
    if (data ~= nil) then
        UnitData:DeleteUnitDataByGUID(data.GUID)
    end
end

function UnitData:DeleteUnitDataByGUID(playerGUID)
    unitInformation[playerGUID] = nil
end

function UnitData:DeleteAllUnitData()
    for guid, unitData in pairs(unitInformation) do
        if unitData.unitId ~= "player" then
            unitInformation[guid] = nil
        end
    end
end