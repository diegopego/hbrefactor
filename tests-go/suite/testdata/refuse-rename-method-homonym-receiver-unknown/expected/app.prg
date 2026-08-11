// Two classes answer the same message, and NOTHING says what `MyClass1()`
// returns: the class function has no declared return type, so `New()` here is
// the inherited one and the receiver of each send is genuinely unknown.
//
// This is the other half of the homonym rename. Where the receiver is a fact
// the tool now acts site by site; where it is not, homonymy IS ambiguity and
// the refusal stands - naming the send it could not place.
#include "hbclass.ch"

CREATE CLASS MyClass1
   METHOD Print()
ENDCLASS

METHOD Print() CLASS MyClass1
   OutStd( "um" )
   RETURN Self

CREATE CLASS MyClass2
   METHOD Print()
ENDCLASS

METHOD Print() CLASS MyClass2
   OutStd( "dois" )
   RETURN Self

PROCEDURE Main()

   LOCAL c1 := MyClass1():New()
   LOCAL c2 := MyClass2():New()

   c1:Print()
   c2:Print()

   RETURN
