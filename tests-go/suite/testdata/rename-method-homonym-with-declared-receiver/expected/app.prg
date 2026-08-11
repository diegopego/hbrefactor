// Two classes answer the same message. The receivers are DECLARED, so the
// compiler knows which one each send reaches - and the rename must act on
// that fact instead of refusing because the name is not unique.
#include "hbclass.ch"

CREATE CLASS MyClass1
   METHOD New() CONSTRUCTOR
   METHOD Show()
ENDCLASS

METHOD New() CLASS MyClass1
   RETURN Self

METHOD Show() CLASS MyClass1
   OutStd( "um" )
   RETURN Self

CREATE CLASS MyClass2
   METHOD New() CONSTRUCTOR
   METHOD Print()
ENDCLASS

METHOD New() CLASS MyClass2
   RETURN Self

METHOD Print() CLASS MyClass2
   OutStd( "dois" )
   RETURN Self

PROCEDURE Main()

   LOCAL c1 AS CLASS MyClass1
   LOCAL c2 AS CLASS MyClass2

   c1 := MyClass1():New()
   c2 := MyClass2():New()

   c1:Show()
   c2:Print()

   RETURN
