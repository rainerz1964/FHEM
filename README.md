# FHEM

## Raumfeld Module for FHEM

<a name="Raumfeld"></a>
<h3>Raumfeld</h3>
<ul>
    <i>Raumfeld_98.pm</i> implements access to a Teufel Raumfeld system via a <a href="https://github.com/ChriD/Raumserver">Raumserver</a>
    It reads the various rooms of the system during intialization as well as the Favourites list and allows you to play the elements in the Favourites list in the
    corresponding room. It allows as well to change the volume in each room. 
    <br><br>
    <a name="Raumfelddefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; Raumfeld &lt;address&gt;</code>
        <br><br>
        Example: <code>define Raumfeld Raumfeld http://127.0.0.1:8585</code>
        <br><br>
        The "address" parameter is the address of the Raumserver.
    </ul>
    <br>
    
    <a name="Raumfeldset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;room&gt; &lt;value&gt;</code>
        <br><br>
        <br><br>
        Options:
        <ul>
              <li><i>title</i><br>
                  Sets either the predefined favorites and plays them or the user defined streams and plays them in a room
                  code>set &lt;name&gt; &lt;room&gt; &lt;value&gt;</code></li>
              <li><i>volume</i><br>
                  Sets the volume of a room to a new &lt;value&gt;
                  <code>set &lt;name&gt; &lt;room&gt; &lt;value&gt;</code></li>
              <li><i>volume</i><br>
                  Switch the power of a room to &lt;on|off&gt;
                  <code>set &lt;name&gt; &lt;room&gt; &lt;on|off&gt;</code></li>
        </ul>
    </ul>
    <br>

    <a name="Raumfeldget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt; &lt;room&gt;</code>
        <br><br>
        You can <i>get</i> the value of any of the options described in 
        <a href="#Raumfeldset">paragraph "Set" above</a>. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
    </ul>
    <br>
    
    <a name="Raumfeldattr"></a>
    <b>Attributes</b>
    <ul>
        <li>none</li>
    </ul>
</ul>


## Integration into FHEM Tablet UI

Integration into the FHEM Tablet UI is implmented with jQuery in index.html using the template file raumfeld.html