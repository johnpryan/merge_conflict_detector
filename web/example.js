var width = 960
var height = 500;

d3.scale.category20();

// create a new force layout with a single node
var force = d3.layout.force()
    .size([width, height])
    .nodes([{}])
    .linkDistance(30)
    .charge(-60)
    .on("tick", tick);

// create an SVG and apply mouse handlers
var svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height)
    .on("mousemove", mousemove)
    .on("mousedown", mousedown);

// returns the current node array
var nodes = force.nodes();

// returns the current link array
var links = force.links();

// all '.node' elements
var node = svg.selectAll(".node");

// all '.link' elements
var link = svg.selectAll(".link");

// add an element for the mouse pointer
var cursor = svg.append("circle")
    .attr("r", 30)
    .attr("transform", "translate(-100,-100)")
    .attr("class", "cursor");

restart();

function mousemove() {
    cursor.attr("transform", "translate(" + d3.mouse(this) + ")");
}

// add a node and link it to any nearby nodes
function mousedown() {
    var point = d3.mouse(this);
    var node = {x: point[0], y: point[1]};
    nodes.push(node);

    // add links to any nearby nodes
    nodes.forEach(function(target) {
        var x = target.x - node.x,
            y = target.y - node.y;
        if (Math.sqrt(x * x + y * y) < 30) {
            links.push({source: node, target: target});
        }
    });

    restart();
}

function tick() {
    // set the properties of the link element to it's d3 source property
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });

    // set the properties of the node element to it's d3 source property
    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });
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
        .attr("r", 5)
        .call(force.drag);

    // must be called after creation, and after assigning nodes and links
    force.start();
}

