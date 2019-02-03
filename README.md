# FHEM

## Raumfeld Module for FHEM

### Raumfeld

*Raumfeld_98.pm* implements access to a Teufel Raumfeld system via a [Raumserver](https://github.com/ChriD/node-raumserver), Documentation can be found [here](https://github.com/ChriD/Raumserver/wiki/Available-control-and-data-requests)
It reads the various rooms of the system during intialization as well as the Favourites list and allows you to play the elements in the Favourites list in the
corresponding room. It allows as well to change the volume in each room. 


#### Define
`define <name> Raumfeld <address>`
    
Example: `define Raumfeld raumfeld http://127.0.0.1:8585`

The `<address>` parameter is the address of the Raumserver.

    
    
#### Set
`set <name> <option> <room> <value>`
Options:
* `title`
    Sets either the predefined favorites and plays them or the user defined streams and plays them in a room
    `set <name> title <room> <value>`
* `volume`
    Sets the volume of a room to a new `<value>`
    `set <name> volume <room> <value>`
* `power`
    Switch the power of a room to `<on|off>`
    `set <name> power <room> <on|off>`

#### Get
`get <name> <option> <room>`
    
You can `get` the value of any of the options described in 
paragraph "Set" above.

#### Readings
For usage with FHEM Tablet UI for each room `<room>` there are three readings available
* `<room>Title`
* `<room>Volume`
* `<room>Power`

If the room name contains white spaces these are eliminated before building the reading

Two addtional readings are available
* `rooms`containing a string of a comma separated list with all rooms in the Ruamfeld system
* `Favorites` a sting of a comma separated lsit with all Favorties, that can be used as values for setting the `title`

#### Attributes
none 


## Integration into FHEM Tablet UI

Integration into the FHEM Tablet UI is implmented with jQuery in index.html using the template file raumfeld.html