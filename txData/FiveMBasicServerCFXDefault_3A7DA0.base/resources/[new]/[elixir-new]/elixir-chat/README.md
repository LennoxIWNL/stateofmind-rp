# Elixir FW - Chat System 4.0

- Hello, first of all thank you for purchasing our script !
- Don't forget to configure the shared/config.lua file according to your server framework.
- Feel free to open a support ticket to resolve your problem/question. - Elixir FW - 

# Commands Avaiables : 
- /ooc (Global OOC)
- /clear (Clear Chat (only client))
- /me

# Here is a short tutorial how to use our chatmessages with our channels/categories

- TriggerEvent("chatMessage", "OOC Elixir FW [123]", 2 , 'OOC Message goes here', 'ooc')
- TriggerEvent('chatMessage', "SYSTEM", { 0, 141, 155 }, "You have been banned from OOC\nReason: Annoying", 'game')
- TriggerEvent('chatMessage', 'DISPATCH ', 2, 'The VIN is scratched off.', 'dispatch')
- TriggerEvent('chatMessage', 'PLAYER REPORT ', {255, 255, 255}, 'Someone reported nobody?', 'staff')



# TUTORIAL : 

<!-- To add the chat suggestions on your register command do like this :  -->

RegisterCommand('me', function(source, args, rawCommand)

<!-- Then, add this trigger bellow in every RegisterCommand -->

  TriggerEvent('chat:addSuggestion', '/me', 'Just a /me', {
    { name = 'me', help = 'Write what do you want.' }
  })

<!---->