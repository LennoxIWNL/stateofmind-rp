function DrawText3D(x,y,z, text)
      local onScreen,_x,_y=World3dToScreen2d(x,y,z)
      local px,py,pz=table.unpack(GetGameplayCamCoords())
      
      SetTextScale(0.35, 0.35)
      SetTextFont(4)
      SetTextProportional(1)
      SetTextColour(255, 255, 255, 215)
    
      SetTextEntry("STRING")
      SetTextCentre(1)
      AddTextComponentString(text)
      DrawText(_x,_y)
      local factor = (string.len(text)) / 370
      DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 41, 11, 41, 68)
  end


  AddEventHandler("BakiTelli_hackermenu:cl:getUsers")
  RegisterNetEvent("BakiTelli_hackermenu:cl:getUsers", function (data)
      SendNUIMessage({
          action = "removePlayer"
      })
    for i = 1, #data do
      getc = json.decode(data[i].charinfo)
    if Current == "LocationCheck" then
      addPlayer(getc.phone , data[i].citizenid)
    else 
      addPlayer(getc.firstname .." ".. getc.lastname , data[i].citizenid)
      end
    end
  end)
  


function addKeys(plate)
  -- add key function 
end