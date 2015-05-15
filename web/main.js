var width = 960
var height = 500;

var color = d3.scale.category20();

var oReq = new XMLHttpRequest();


oReq.onload = function(e) {
    adjencyList = JSON.parse(oReq.responseText);
    generateData();
    restart();
}
oReq.open("GET", "/graph.json", true);
oReq.responseType = "text";
oReq.send();

var adjencyList = {};

var adjencyObjects = {};
var nodeData = [];
var linkData = [];

function generateData() {
    nodeData = [];
    linkData = [];
    for (var key in adjencyList) {
        if (adjencyList.hasOwnProperty(key)) {
            adjencyObjects[key] = {name: key};
            nodeData[nodeData.length] = adjencyObjects[key];
        }
    }

    for (var key in adjencyList) {
        if (adjencyList.hasOwnProperty(key)) {
            for (var i = 0; i < adjencyList[key].length; i++) {
                linkData[linkData.length] = {source: adjencyObjects[key], target: adjencyObjects[adjencyList[key][i]]};
            }
        }
    }
    force = d3.layout.force()
    .size([width, height])
    .nodes(nodeData)
    .links(linkData)
    .linkDistance(90)
    .charge(-300)
    .on("tick", tick);

    nodes = force.nodes();
    links = force.links();
    node = svg.selectAll(".node");
    link = svg.selectAll(".link");
    text = svg.selectAll(".text");
}


// create a new force layout with a single node
var force = d3.layout.force()
    .size([width, height])
    .nodes(nodeData)
    .links(linkData)
    .linkDistance(60)
    .charge(-60)
    .on("tick", tick);

// create an SVG and apply mouse handlers
var svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height);

// returns the current node array
var nodes = force.nodes();

// returns the current link array
var links = force.links();

// all '.node' elements
var node = svg.selectAll(".node");

// all '.link' elements
var link = svg.selectAll(".link");

var text = svg.selectAll(".text");

restart();

function tick() {
    // set the properties of the link element to it's d3 source property
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });

    // set the properties of the node element to it's d3 source property
    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });

    text.attr("x", function(d) {return d.x - 0;});
    text.attr("y", function(d) {return d.y + 22;});
}

function restart() {
    // join the link elements data to the links array
    // returns an update selection (elements that were updated)
    link = link.data(links);

    // enter() returns placeholder nodes for data elements with no
    // DOM element.
    // this draws a line before any 'node' elements (so they appear behind them)
    link.enter().insert("line", ".node")
        .attr("class", "link");

    // join the node elements
    node = node.data(nodes);

    // draw any edges that havent been drawn
    node.enter().insert("circle", ".cursor")
        .attr("class", "node")
        .attr("r", 6)
        .style("fill", function(d) {return color(nodeData.indexOf(d));})
        .call(force.drag);

    text = text.data(nodes);
    text.enter().insert("text", ".circle").text(function(d) {return d.name});

    // must be called after creation, and after assigning nodes and links
    force.start();
}

