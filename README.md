# 🌚 moontrace

Experimental ray tracer written in [Luau](https://luau.org/) with [Lute](https://lute.luau.org/). Early stage.

![moontrace](docs/images/showcase.png)

## Quick Start

Clone the repository:
```sh
git clone https://github.com/prominly/moontrace.git
cd moontrace
```

This project requires the `Lute` runtime. You can find the local setup instructions on this [Page](https://lute.luau.org/guide/installation.html).

Before rendering the scene, you may want to adjust the sample count. This can be done by changing the `SAMPLES` variable at the top of `src/main.luau`.

Performance depends on your hardware, but 10 samples per pixel shouldn't take more than a minute at the moment.
> _the render above took 500 samples per pixel._

Launch:
```sh
lute run src/main.luau
```
> Note: the final image will be in `.ppm` format.

## References

- [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html)

