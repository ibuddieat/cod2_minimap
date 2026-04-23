# Call of Duty 2 Minimap

A Call of Duty 4 styled minimap for Call of Duty 2.

Resources needed from Call of Duty 4 are not included here for copyright reasons, see [this](https://github.com/ibuddieat/cod2_minimap/blob/1a3abc190715c3f312a676017600616efa62f920/codescripts/minimap.gsc#L73) for additional notes.

This is just a proof of concept, do not ask me to adjust or otherwise fix this for you ;)

See this in action on [YouTube](https://youtu.be/Az3qaJSxWRY).

## Notes regarding `SetClock()`

In the given script, the first parameter (the rotational angle of the image) passed to this function is always scaled by `1000`. This is to avoid visible rotation between two server frames, because ... well it's a clock :) On a 360 degree scale, this would appear as a small but visible wiggle of the hud element.

Also, the set angle cannot be `0`, so in that case a full rotation of the clock is added.

The material specified for the clock is `zk_minimap_mp_toujane`, but the actually visible (and rotating) part is the clock's needle `zk_minimap_mp_toujaneneedle` (the "needle" string is a hard-coded suffix), and both materials/shaders need to be precached.

## Asset Manager: Stencil Options for Image Masking

From a rendering perspective, what's happening here is a classic two-pass stencil setup:
- First draw: writing a shape into the stencil buffer (using the `zk_stencil_mask` material)
- Second draw: render an image only where the stencil was written (`zk_minimap_mp_toujaneneedle` material, for example)

In the material system of Call of Duty 2 (which is very similar to how Quake 3 works), this maps directly to a stencil write pass (first draw) and a stencil test pass (second draw). Also, in the context of 2D hud elements, for this to be applied in the correct order in the game, the mask material needs to have a lower `hud.sort` value than the image material that comes "on top".

3D textures (xmodels etc.) are not explained here as I did not run any tests with those, but the same technique could be applied to make certain parts of or complete textures only visible through those customizable settings, in both 1st-person and 3rd-person view.

Let's see the `zk_stencil_mask` material in Asset Manager:
<img width="737" height="408" alt="grafik" src="https://github.com/user-attachments/assets/d21c10df-ed0c-40ce-9b8a-107db908e23c" />

#### Color map

The referenced `zk_black.dds` is a 4x4 pixel black image and can be scaled in size as needed through the call to `SetShader()`, or `SetClock()` if the mask itself should support rotation. The image could also use another color, but wherever the image on top is transparent, the given color will become visible. This can be seen at the compass tape, giving it its intended dark background.

<img width="609" height="147" alt="grafik" src="https://github.com/user-attachments/assets/19c370e0-1fb3-4be5-aa1c-e6d1fc8874a0" />

#### Advanced Options

This material should not render visible color on its own, so all `Color Write` fields are set to `Disable`. It is the "mask" that, in the first draw, should only write to the stencil buffer.

`Stencil` is set to `One-sided` since we can see the material only from one side anyway. `Function` is `Always`, `Fail` is `Keep`, `Z-fail` is `Keep` and `Pass` is `Invert` (more on those later).

#### Framebuffer operations

Since color is disabled for that material, the setting of `blendFunc` does not matter too much, but here it's set to `Blend` so we can use it as the half-transparent background for the compass tape.

Then we set `depthTest` to `Always` and `depthWrite` to `Disable`. Even for 2D elements, depth testing is still part of the rendering pipeline, so it can interfere with stencil, depending on the possible outcomes of the depth test:
- `Fail`: The stencil `Function` failed
- `Z-fail`: Stencil passes, depth fails
- `Pass`: Both pass

If `depthTest` is not `Always`, the stencil write may never hit the `Pass` path.

For the `Pass` case, the setting `Invert` is used because the game's internal stencil reference value is `0`. So with this, the results will be:
- Outside mask → stencil = 0
- Inside mask → stencil = non-zero (255, for example)

Now comes the image material `zk_minimap_mp_toujaneneedle` on top:
<img width="737" height="407" alt="grafik" src="https://github.com/user-attachments/assets/66c0b567-7768-4f51-9a07-a9f5f60e3324" />

Its settings need to correctly play together with the `zk_stencil_mask` material settings, leading to the following notable differences:
- `alphaTest` is now set to `GT0`, which is "Greater Than Zero" so that only non-transparent mask pixels affect the color draw
- `Color Write` is now enabled, since we want to see this image
- The stencil `Function` is set to `NotEqual` because at this point we don't know the exact value in the stencil buffer (255 vs. others), but due to the `Invert` we do know that it's not `0`
- `Pass` is now set to `Keep` to apply/draw the color and alpha data of the respective pixel(s) from the image material

This is just one working example using the stencil operations and depending on the use case (3D textures, giving the mask soft half-transparent edges etc.), other settings or mask base images might be necessary.
