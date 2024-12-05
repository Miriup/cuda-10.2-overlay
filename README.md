# cuda-10.2-overlay
Gentoo portage overlay with backported ebuilds to support CUDA 10.2

This overlay contains Gentoo packages taken from the main tree - sometimes with
backports - to allow running CUDA 10.2 with an otherwise up to date package
database.

I'm fully aware that his is a Don Quixote effort as more and more patches will
be required as time progresses. NVIDIA, for example, have just recently dropped
support for their 470 series Linux kernel driver. But for now it looks as if
it's still possible to number crunch ML models with fairly ancient GPU and a
fairly modern operating system.

My particular aim is to support my NVIDIA GeForce 750M card with as little
ancient packages as possible. When backporting I have tried to rely on existing
commits in pytorch and related packages whenever possible.  Originally I had
ported ONNX 1.8.1 but then I found a single pytorch commit that would allow me
to compile it against a recent version. I keep the old port in the overlay in
case anyone has a specific concern and wants to base their work on my backport.

pytorch 1.7.0 requires python 3.10. The commits in the pytorch repository that
lift pytorch to be compatible with python 3.11 are very complex. Depending on
python 3.10, which is said to be significantly slower than more recent
versions, was the most viable path forward.

