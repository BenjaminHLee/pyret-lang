import global as global
import chart-lib as P
import list as L

################################################################################
# CONSTANTS
################################################################################


################################################################################
# TYPE SYNONYMS
################################################################################

type Posn = RawArray<Number>

################################################################################
# HELPERS
################################################################################


################################################################################
# METHODS
################################################################################


################################################################################
# BOUNDING BOX
################################################################################

type BoundingBox = {
  x-min :: Number,
  x-max :: Number,
  y-min :: Number,
  y-max :: Number,
  is-valid :: Boolean
}

default-bounding-box :: BoundingBox = {
  x-min: 0,
  x-max: 0,
  y-min: 0,
  y-max: 0,
  is-valid: false,
}

#fun get-bounding-box(ps :: L.List<Posn>) -> BoundingBox:
#  cases (L.List<RawArray<Number>>) ps:
#    | empty => default-bounding-box.{is-valid: false}
#    | link(f, r) =>
#      fun compute(p :: (Number, Number -> Number), accessor :: (Posn -> Number)):
#        for fold(prev from accessor(f), e from r): p(prev, accessor(e)) end
#      end
#      default-bounding-box.{
#        x-min: compute(num-min, fst),
#        x-max: compute(num-max, fst),
#        y-min: compute(num-min, snd),
#        y-max: compute(num-max, snd),
#        is-valid: true,
#      }
#  end
#end

################################################################################
# DEFAULT VALUES
################################################################################


################################################################################
# DATA DEFINITIONS
################################################################################


################################################################################
# FUNCTIONS
################################################################################


################################################################################
# PLOTS
################################################################################

