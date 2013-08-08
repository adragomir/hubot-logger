# hubot-logger
============

## Usage

1. install dependencies (Redis, Node.js)
2. clone [Hubot IRC Runnable](https://github.com/jgable/hubot-irc-runnable) to whatever you want to call your new bot
3. change to the new folder for the bot
4. add a file called external-scripts.json that contains this ["hubot-logger"]
5. edit package.json to have hubot-logger as a dependency
6. 
```
npm install
```
7. edit the hubot-scripts.json to suit whatever scripts you want

   (note: tweet.coffee was broken at time of this writing, you may want to delete it from this file)
   
8. edit the environmental variables in runbot.sh to what you want
  
    add IRCLOGS_FOLDER with path to where you want to store your logs

    add line that specifies IRCLOGS_PORT if you want something other than 8086

9.
```
./runbot.sh
```

You can then access your logs in a web browser at localhost:8086/irclogs (change port if you specified something different).

Enjoy Hubot Logging your IRC channels!
