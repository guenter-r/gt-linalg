## -*- coffee -*-

<%inherit file="base_diptych.mako"/>

<%block name="title">The function Ax=b</%block>

<%block name="inline_style">
${parent.inline_style()}
#inconsistent {
    font-weight:   bold;
    font-size:     120%;
    padding-left:  1em;
    padding-right: 1em;
    color:         red;
    display:       none;
}
#matrix-here {
    display: none;
    text-align: center;
}
.overlay-text > p:last-child {
    text-align: center;
}
</%block>

<%block name="overlay_text">
<div class="overlay-text">
  <p id="matrix-here"><span id="the-matrix"></span></p>
  <p><span id="the-equation"></span>
      <span id="inconsistent">inconsistent</span></p>
  <p>[Click and drag the heads of x and b]</p>
</div>
</%block>

<%block name="label1">
<div class="mathbox-label">Input</div>
</%block>

<%block name="label2">
<div class="mathbox-label">Output</div>
</%block>


##

##################################################
# Globals
vector    = [-1, 2, 3]
outVec    = [0, 0, 0]
colBasis  = []
showSolnsKey = "Show solution set"
lockSolnsKey = "Lock solution set"

solve         = null
solnspace     = null
params        = null
labeled       = null
updateCaption = null

matrix = [[ 1, -1,  2],
          [-2,  2, -4]]
if urlParams.mat?
   matrix = urlParams.mat.split(":").map (s) -> s.split(",").map parseFloat
rows = matrix.length
cols = matrix[0].length

# Make 3x3, first coord = column
tmp = []
for i in [0...3]
    tmp[i] = []
    for j in [0...3]
        tmp[i][j] = matrix[j]?[i] ? 0
matrix = tmp


window.demo1 = new (if cols == 3 then Demo else Demo2D) {
    mathbox: element: document.getElementById "mathbox1"
    scaleUI: false
}, () ->
    window.mathbox1 = @mathbox

    ##################################################
    # Demo parameters
    @showSolns = true
    @lockSolns = false
    if @urlParams.captions == 'rankthm'
        vector = [0, 0, 0]
    if @urlParams.show?
        @showSolns = if @urlParams.show == 'false' then false else true
    if @urlParams.lock?
        @lockSolns = if @urlParams.lock? then true else false
    @range = @urlParams.range1 ? 5

    if @urlParams.x?
        vector = @urlParams.x.split(",").map parseFloat
    vector[2] ?= 0
    vector[2] = 0 if cols == 2

    @tMatrix = new THREE.Matrix3()
    @tMatrix.set matrix[0][0], matrix[1][0], matrix[2][0],
                 matrix[0][1], matrix[1][1], matrix[2][1],
                 matrix[0][2], matrix[1][2], matrix[2][2]

    # Scratch
    tmpVec = new THREE.Vector3()

    ##################################################
    # gui
    params =
        Axes: not (@urlParams.axes in ['off', 'disabled'])
        Homogeneous: () =>
            vector[0] = vector[1] = vector[2] = 0
            params[showSolnsKey] = true
            params[lockSolnsKey] = true
            solnspace.setVisibility true
            computeOut()
    params[showSolnsKey] = @showSolns
    params[lockSolnsKey] = @lockSolns

    gui = new dat.GUI width: 350
    gui.closed = @urlParams.closed?
    gui.add(params, 'Axes').onFinishChange (val) =>
        @mathbox.select(".view1-axes").set 'visible', val
        demo2.mathbox.select(".view2-axes").set 'visible', val
    gui.add(params, showSolnsKey).listen().onFinishChange (val) =>
        solnspace.setVisibility val
    gui.add(params, lockSolnsKey).listen()
    gui.add params, 'Homogeneous'

    ##################################################
    # view, axes
    r = @range
    view = @view
        name:       'view1'
        viewRange:  [[-r,r], [-r,r], [-r,r]][0...cols]
        axisLabels: false
    @mathbox.select(".view1-axes").set 'visible', params.Axes

    ##################################################
    # labeled vector
    labeled = @labeledVectors view,
        vectors:       [vector]
        colors:        [[0, 1, 0, 1]]
        labels:        ['x']
        live:          true
        zeroPoints:    true
        zeroThreshold: 0.1
        vectorOpts:    zIndex: 2
        labelOpts:     zIndex: 3
        zeroOpts:      zIndex: 3

    ##################################################
    # Clip cube
    clipCube = @clipCube view,
        draw:   cols == 3
        hilite: cols == 3
        color:  new THREE.Color .75, .75, .75
        material: new THREE.MeshBasicMaterial
            color:       new THREE.Color 0.5, 0, 0
            opacity:     0.5
            transparent: true
            visible:     false
            depthWrite:  false
            depthTest:   true

    ##################################################
    # Solution set
    [nulBasis, colBasis, Emat, solve] \
        = @rowred (c.slice() for c in matrix), {rows: rows, cols: cols}
    @nulspace = solnspace = @subspace
        name:    'nulspace'
        vectors: nulBasis
        live:    false
        mesh:    clipCube.mesh
    tform = clipCube.clipped.transform().bind position: () => vector
    solnspace.draw tform
    if solnspace.dim == 3
        clipCube.installMesh()
    solnspace.setVisibility params[showSolnsKey]

    ##################################################
    # Dragging
    computeOut = () =>
        tmpVec.set.apply(tmpVec, vector).applyMatrix3 @tMatrix
        outVec[0] = tmpVec.x
        outVec[1] = tmpVec.y
        outVec[2] = tmpVec.z
        updateCaption()

    onDrag = (vec) =>
        if params[showSolnsKey] and params[lockSolnsKey]
            tmpVec.set.apply tmpVec, vector
            solnspace.project vec.sub(tmpVec), vec
            vec.add tmpVec

    @draggable view,
        points:   [vector]
        onDrag:   onDrag
        postDrag: computeOut

    ##################################################
    # Caption
    eqnElt = document.getElementById 'the-equation'
    inconsElt = document.getElementById 'inconsistent'
    switch @urlParams.captions
        when 'rankthm'
            document.getElementById('matrix-here').style.display = 'block'
            str = @texMatrix matrix,
                rows:      rows
                cols:      cols
                precision: -1
            katex.render 'A=' + str, document.getElementById('the-matrix')
            katex.render """
                            \\text{rank}(A) = #{cols-solnspace.dim} \\qquad
                            \\text{dim Nul}(A) = #{solnspace.dim} \\qquad
                            \\#\\text{ columns of } A = #{cols}
                         """, eqnElt
            updateCaption = () ->
        else
            updateCaption = () =>
                str = @texMatrix matrix,
                    rows:      rows
                    cols:      cols
                    precision: -1
                if labeled.hidden
                    katex.render str \
                        + '\\color{#00ff00}{x}' \
                        + ' = ' \
                        + @texVector(outVec, {color: '#ffff00', dim: rows}),
                        eqnElt
                    inconsElt.style.display = 'inline'
                else
                    katex.render str \
                        + @texVector(vector, color: '#00ff00', dim: cols) \
                        + ' = ' \
                        + @texVector(outVec, {color: '#ffff00', dim: rows}),
                        eqnElt
                    inconsElt.style.display = 'none'

    computeOut()


window.demo2 = new (if rows == 3 then Demo else Demo2D) {
    mathbox: element: document.getElementById "mathbox2"
    scaleUI: false
}, () ->
    window.mathbox2 = @mathbox

    ##################################################
    # view, axes
    @range = @urlParams.range2 ? 10
    r = @range
    view = @view
        name:       'view2'
        viewRange:  [[-r,r], [-r,r], [-r,r]][0...rows]
        axisLabels: false
    @mathbox.select(".view2-axes").set 'visible', params.Axes

    ##################################################
    # labeled vector
    @labeledVectors view,
        vectors:       [outVec]
        colors:        [[1, 1, 0, 1]]
        labels:        ['b']
        live:          true
        zeroPoints:    true
        zeroThreshold: 0.3
        vectorOpts:    zIndex: 2
        labelOpts:     zIndex: 3
        zeroOpts:      zIndex: 3

    ##################################################
    # Clip cube
    clipCube = @clipCube view,
        draw:   rows == 3
        hilite: rows == 3
        color:  new THREE.Color .75, .75, .75
        material: new THREE.MeshBasicMaterial
            color:       new THREE.Color 0.5, 0, 0
            opacity:     0.5
            transparent: true
            visible:     false
            depthWrite:  false
            depthTest:   true

    ##################################################
    # Column span
    subspace = @subspace
        name: 'colspace'
        vectors: colBasis
        live: false
    subspace.draw clipCube.clipped

    if subspace.dim == 3
        clipCube.installMesh()
        clipCube.mesh.material.visible = true

    ##################################################
    # Dragging
    snapThreshold = 1.0 * 10.0 / @range
    snapped = new THREE.Vector3()
    diff = new THREE.Vector3()

    # Snap to column span
    onDrag = (vec) =>
        subspace.project vec, snapped
        diff.copy(vec).sub snapped
        if diff.lengthSq() <= snapThreshold
            vec.copy snapped

    computeIn = () ->
        inVec = solve outVec
        if inVec?
            # Find solution closest to current vector
            inVec[2] ?= 0
            tmpVec.set vector[0]-inVec[0], vector[1]-inVec[1], vector[2]-inVec[2]
            solnspace.project tmpVec, tmpVec
            vector[0] = tmpVec.x + inVec[0]
            vector[1] = tmpVec.y + inVec[1]
            vector[2] = tmpVec.z + inVec[2]
            demo1.nulspace.setVisibility params[showSolnsKey]
            labeled.show()
        else
            # So the zero point doesn't show up
            demo1.nulspace.setVisibility false
            labeled.hide()
        updateCaption()

    tmpVec = new THREE.Vector3()
    @draggable view,
        points: [outVec]
        onDrag: onDrag
        postDrag: computeIn


groupControls demo1, demo2