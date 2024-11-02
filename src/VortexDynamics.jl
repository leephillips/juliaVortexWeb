module VortexDynamics

using HTTP, JSON, Printf

export evolve_vortices, tseries, flowfield


const VPORT = 8995
const ds = 0.01
x = 0:ds:1
y = 0:ds:1
const nx = 20
const ARENA = 40.0

"""Calculates the flow field created by a collection of vortices.
`va` is an array of vectors `[x, y, ω]` containing the coordinates
and vorticity of each vortex. Returns `[vx, vy]` at the input
`x` and `y` coordinates. `ωs` is the vorticity scaling and `a` 
is the vortex diameter."""
function flowfield(va, x, y; a=1/20, ωs=1.0)
    v = [0.0, 0.0]
    for vortex in va
        r = sqrt((x-vortex[1])^2 + (y-vortex[2])^2)
        θ = atan(y-vortex[2], x-vortex[1]) - π/2
        if r <= a
            v = v .+ [cos(θ), sin(θ)].*(ωs*vortex[3]*r/a)
        else
            v = v .+ [cos(θ), sin(θ)].*(ωs*vortex[3]*(a/r))
        end
    end
    return v
end

"""Updates position of each vortex from the total flowfield at its location."""
function update(va, ws, PID, dt=0.01, i=0; a=1/20, ωs=1.0)
    for vortex in va
        v = flowfield(va, vortex[1], vortex[2]; a, ωs)
        vortex[1] = vortex[1] + dt * v[1]
        vortex[2] = vortex[2] + dt * v[2]
    end
end

function tseries(va, ws, PID, dt=0.01, nt=100; a=1/50, ωs=1.0)
    lva = length(va) 
    vaseries = fill([0.0, 0.0, 0], nt, lva)
    vaseries[1, :] = deepcopy(va)
    for i in 2:nt
        update(va, ws, PID, dt, 0; a, ωs)
        vaseries[i, :] = deepcopy(va)
    end
    return vaseries
end

"""Return the (x,y) coordinates of the element with index `i`.
Coordinates are normalized to go `0 → 1` (almost)."""
function itoxy(i)
    x = (i-1.0)%nx / nx
    y = 1.0 - floor((i-1.0)/nx) / nx
    return [x, y]
end

function evolve_vortices()
    WebSockets.listen!("127.0.0.1", VPORT) do ws
        PID = readchomp(`uuidgen`)
        a = 1 # vortex radius
        ω = 1 # vorticity
        va = [] # vortex array
        for msg in ws
            rec = JSON.parse(msg)
            delete!(rec, "HEADERS")
            delete!(rec, "pn")
            for v in rec
                append!(va, [[itoxy(Meta.parse(v[1])); Meta.parse(v[2])]])
            end
                vaseries = tseries(va, ws, PID, 0.04, 1000; a=1/50)
                vastring = String[]
                append!(vastring, ["""<div id="swim" hx-swap-oob='true'>"""])
                for i in eachcol(vaseries)
                    x = join(first.(i), " ")
                    y = join(getindex.(i, 2), " ")
                    if i[1][3] == 1
                        color = "blue"
                    else
                        color = "green"
                    end
                    append!(vastring, ["""<input class='swimmers' type="checkbox" style="position:absolute; border-radius: 2cqw; border:solid $color 1cqw; left:$(i[1][1]*ARENA)cqw; top:$(ARENA - i[1][2]*ARENA)cqw;" x="$x" y="$y">"""])
                end
                append!(vastring, ["""</div>"""])
                WebSockets.send(ws, vastring)
                WebSockets.send(ws, """<div id="waiting" hx-swap-oob='true' style="display:none"></div>""")
                WebSockets.send(ws, """<script id='moveit' hx-swap-oob='true'>move();</script>""")
        end
    end
end


# Examples:
#
# Smokering leapfrog: va = [[0.25,0.25,1], [0.25, 0.75, -1], [0.125, 0.375, 1], [0.125, 0.625, -1]]


end # module VortexDynamics
