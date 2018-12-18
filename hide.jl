using DynamicEnergyBudgets

import Base: show
using Base.StackTraces: StackFrame, empty_sym

# function Base.show(io::IO, frame::StackFrame; full_path::Bool=false)
#     file_info = full_path ? string(frame.file) : basename(string(frame.file))
#     print(io, " at ")
#     Base.with_output_color(get(io, :color, false) && get(io, :backtrace, false) ? Base.stackframe_lineinfo_color() : :nothing, io) do io
#         print(io, file_info, ":")
#         if frame.line >= 0
#             print(io, frame.line)
#         else
#             print(io, "?")
#         end
#     end
# end
function show(io::IO, frame::StackFrame; full_path::Bool=false)
    # show_spec_linfo(io, frame)
    if frame.file !== empty_sym
        file_info = full_path ? string(frame.file) : basename(string(frame.file))
        # print(io, " at ")
        Base.with_output_color(get(io, :color, false) && get(io, :backtrace, false) ? Base.stackframe_lineinfo_color() : :nothing, io) do io
            print(io, file_info, ":")
            if frame.line >= 0
                print(io, frame.line)
            else
                print(io, "?")
            end
        end
    end
    if frame.inlined
        print(io, " [inlined]")
    end
end

# Base.show(io::IO, x::Organ) = show(io,"Organ")
# Base.show(io::IO, x::SharedParams) = show(io,"SharedParams")
# Base.show(io::IO, x::Organism) = show(io,"Organism")
# Base.show(io::IO, x::Vars) = show(io,"Vars")
# Base.show(io::IO, x::ParamsCNE) = show(io,"ParamsCNE")
# Base.show(io::IO, x::ParamsCN) = show(io,"ParamsCN")
# Base.show(io::IO, x::Records) = show(io,"Records")