CreateRegisterItem(Config.ItemName)

QBCore.Commands.Add('givedocs', "Give yourself documents", {}, false, function(source)
    exports["five-idcard"]:CreateMetaLicense(source)
end, 'admin')