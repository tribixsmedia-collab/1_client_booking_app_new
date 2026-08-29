# Razorpay Checkout.
#
# R8 strips the SDK's callback classes because nothing in our Dart code
# references them by name -- payments then fail only in release builds, with no
# error, which is a miserable thing to debug. These rules keep them.
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
