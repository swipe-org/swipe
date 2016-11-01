# Swipe Language Specification

## Abstract

This specification defines the features and syntax of Swipe, a mark-up language for non-developers to create media-rich and animated documents for touch-enabled devices.

## Status of this document

This specification describes the current snapshot of the Swipe 0.1, which is still under development and may change drastically.

## 1. Introduction

Swipe is a domain-specific, declarative language for non-developers (such as designers, animators, illustrators, musicians, videographers and comic writers) to create media-rich documents (books and presentations) that contains photos, videos, vector graphics, animations, voices, music and sound effects, which will be consumed on touch-enabled devices (such as smartphones, tablets and touch-enabled set-top-boxes). 

Since the introduction of iPhone, the capability of those mobile devices advanced significantly with faster CPU/GPU, a large amount memory and various sensors, but taking a full advantage of those capability is not easy.

While the "native programming" (such as in Objective-C, Swift, Java, and etc.) gives the best possible performance and the user experience, the development cost is very expensive, and supporting multiple devices is a nightmare.

Using a "cross-platform development environment", such as Unity, Coco3D, Corona and Flash has some advantages over native programming, but it still requires a "procedural programming", which only skilled developers are able to do. 

Building interactive applications on top of HTML browsers became possible because of HTML5, but it still has many issues. Providing a good user experience is very difficult (this is why Facebook gave up this approach), and the development cost is as expensive as native or cross-platform development, requiring skilled developers.

People often debate over those three approaches, but they often overlook one important disadvantage of those three approaches. All those approaches require "procedural programming", which can be done only by skilled developers and are very expensive, error-prone and time-consuming. 

This disadvantage makes it very difficult for those creative people to make quick prototypes and experimental works, just like an artist makes sketches with pencils and erasers. It is economically impossible for individual creators to create interactive, media-rich books and publish them. 

Swipe was born to fill this gap. It allows non-developers to create interactive and media-rich documents without any help from developers. The declarative nature of Swipe language (and the lack of "procedural programming environment") makes very easy to learn, write and read. It also makes it easy to auto-generate documents (from data) and create authoring environments. 

### Scope

Swipe was designed for a specific set of applications and contents. 

- Animated Comics
- Animated Children Books
- Sound Novels (Story book with pictures, BGM and sound-effects)
- Graphical Audio Books
- Photo & Video Books
- Graphical Music Albums
- Media-rich Presentations
- Video Instructions & Tutorials

Swipe is NOT 

- A replacement of ePub, which is designed for text-centric books and supports flow layout
- A general-purpose programming environment where programmers write procedural code
- A game engine
 
### Design Principles

- Domain-specific (not general purpose)
- Declarative (not a programming environment)
- JSON instead of XML
- Lightweight
- Designer friendly

### Data Types

- **String**: Regular string
- **Color**: One of RBG(A) styles ("#RRGGBB", "#RGB", "#RRGGBBAA", "#RGBA") or, one of standard color names ("red", "black", "blue", "white", "green", "yellow", "purple", "gray", "darkGray", "lightGray", "brown", "orange", "cyan", "magenta")
- **Percent**: "NN%" relative to the parent
- **Path**: SVG-style Path String
- **URL**: relative or absolute URL
- **StringId**: Regular string used as an identifier
- **LangId**: Language identifier, such as "\*", "en", "ja", "de", etc., where "\*" represents the default

## 2. Document

A **Document** is a UTF8 JSON file, which consists of a collection of **Pages**. The order of **Pages** in the collection is significant, and they will be presented to the user in the specified order. 

Here is a sample **Document** which consists of two pages:

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"Good Bye!" }
            ]
        }
    ]
}
```
When the user opens this document with a Swipe viewer, the user will see only the first page with text "Hello World!" in the middle of screen. The user needs to swipe up (since the vertical scrolling is the default) to see the second page.

### Document Properties

- **type** (String): This must be "net.swipe.swipe" for a Swipe document
- **version** (String): Version of the Swipe language specification used in the document
- **title** (String): Title of the document, optional
- **bc** (Color): Background color, default is *Black*
- **dimension** ([Int, Int]): Dimension of the document, default is [320, 568]
- **paging** (String): Paging direction, *vertical* (default), or *leftToRight*
- **orientation** (String): Document orientation, *portrait* (default) or *landscape*
- **templates** ({"elements":ElementTemplates, "pages":PageTemplates})
 - **pages** ({Name:PageTemplate}): **PageTemplate** dictionary
 - **elements** ({Name:ElementTemplate}):	 **ElementTemplate** dictionary
- **paths** ({Name:Path}): Named **Paths** dictionary
- **markdown** ({Name:Style}): Named **Markdown** style
- **voices** ({Name:VoiceInfo}): Named **Voice** style
- **pages** ([Page,...]): Collection of **Pages**
- **resources** ([String,...]): Resource keys for on-demand resources
- **viewstate** (Bool): Indicate if we need to save&restore view state. The default is true. 
- **languages** ({"id":LangId, "title":String},...): Languages to display via the "Lang." button in the Swipe viewer.


## 3. Page

**Page** consists of a collection of **Elements**. The order of **Elements** in the collection is significant, those elements will be rendered in the specified order (from bottom to top). 

Here is a **Document** with a **Page**, which has two **Elements**. 

```
{
    "pages": [
        {
            "elements": [
                { "x":50, "y":100, "w":100, "h":100, "bc":"red" },
                { "x":100, "y":150, "w":100, "h":100, "bc":"blue" }
            ]
        }
    ]
}
```

### Page Properties

- **bc** (Color): Background color, the default is *white*
- **fps** (Int): Frame per second, the default is 60
- **transition** (String): Inter-page transition style, *scroll* (default), *fadeIn* or *replace*
- **play** (String): Play(animation) control, *auto* (default), *pause*, *always* or *scroll*
- **duration** (Float): Duration of the animation in seconds, the default is 0.2 seconds
- **repeat** (Boolean): Repeat rule of the animation, default is *false*
- **rewind** (Boolean): Rewind rule of the animation when the user leaves the page, default is *false*
- **template** (String): Name of the *PageTemplate*, default is "\*"
- **audio** (URL): Specifies the sound effect to be played in sync with the animation
- **speech** (SpeechInfo): Specifies the text-to-speech to be played in sync with the animation
- **vibrate** (Bool): Specifies the vibration in sync with the animation, the default is false
- **elements** ([Element+]): Collection of Elements
- **eyePosition** (Float): Eye position (z-height) for the perspective relative to width, default is 1.0
- **strings** ([StringId:[LangId:String]]): String resources
- **id** (String): Identifier used in Actions to reference the page
- **events** ([Event+]): List of Events

### Page Events
- **loaded**: The page is loaded into the viewer and ready to display
- **tapped**: The user singled-tapped on the page
- **doubleTapped**: The user double-tapped on the page

## 4. Paging direction, inter-page transition and animation

The paging direction is defined by the "paging" property of the **Document**. It must be either *vertical*, *leftToRight* or *rightToLeft*, and the default is *vertical*.

The inter-page transition is defined by the "transition" property of the preceding **Page**. It should be either *scroll*, *fadeIn* or *replace*. The default is *scroll* unless the "play" property is *scroll*. If the "play" property is *scroll*, the default is *replace*.

### Values for the "transition" property

- *scroll*: regular scrolling behavior (default)
- *fadeIn*: The preceding **Page** will fade-in while the user drags it in.
- *replace*: The preceding **Page** will replace when the user start dragging.

The "play" property defines the timing of play/animation defined on the **Page**, and it must be either *auto*, *pause*, *always* or *scroll*. If "auto" is specified, the animation will start automatically after the completion of the forward paging action. If "always" is specified, the animation will start after the completion of the backward paging action as well. If *scroll* is specified, the animation will be played while the user is scrolling the page. 

### Values for the "play" property

- *auto*: The animation on the **page** will be played after forward scrolling to this page (default)
- *pause*: The animation on the **Page** will not automatically start
- *always*: The animation on the **Page** will be played after scrolling to this page
- *scroll*: The animation on the **Page** will be performed while the user scrolls the page
- *never*: Page animations are disabled for the **Page**.  Used when a page contains Actions that perform animations

## 5. Page Template

A **PageTemplate** defines a set of properties and **Elements** to be shared among multiple **Pages**. It also defines a background music to be played when one of those **Pages** is active.

A **Page** is always associated with a **PageTemplate**, either explicitly with the "template" property or implicitly with the default **PageTemplate** with name "*".

The **Page** inherits all the properties from the associated **PageTemplate**, including **Elements**. When the same property is specified both in the **Page** and the **PageTemplate**, the value specified in the **Page** will be used. The only exception to this rule is **Elements**, which will be deep-merged (deep-inheritance). **Elements** with the *id* property will be merged, and other **Elements** will be appended (**Elements** defined in the **PageTemplate** are always placed below **Elements** specified in the page).

Here is a **Document** with two **Pages**, where the first **Page** is associated with the default **PageTemplate**, and the second **Page** is associated with the "alternative" **PageTemplate**. Because each **PageTemplate** specifies the background color, those **Pages** inherit those background colors.   

```
{
    "templates": {
        "pages": {
            "*": { "bc":"blue" },
            "alternative": { "bc":"green" }
        }
    },
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "template":"alternative",
            "elements": [
                { "text":"Good Bye!" }
            ]
        }
    ]
}
```

The following example uses the "id" to identify a particular **Element** in the **PageTemplate** and modify its "textColor" property.

```
{
    "templates": {
        "pages": {
            "*": {
                "elements": [
                    { "id":"hello", "text":"Hello World" }
                ]
            }
        }
    },
    "pages": [
        {
            "elements": [
                { "id":"hello", "textColor":"red" }
            ]
        },
        {
            "elements": [
                { "id":"hello", "textColor":"green" }
            ]
        }
    ]
}
```

### PageTemplate specific properties
- bgm (URL): Specifies the background music to play.

## 6. Element

An **Element** is a visible entity on a **Page**. It occupies a specified rectangle area within a **Page**. An **Element** may contain child **Elements**. 

### Element properties

- **id** (String): the element identifier in the associated **ElementTemplate** at the same nesting level
- **visible** (Bool): the visibility of the element, default is true, not animatable.
- **template** (String): the name of the **ElementTemplate** to inherit properties from
- **x** (Float or Percent): x-position of the left-top corner of element, default is 0
- **y** (Float or Percent): y-position of the left-top corner of the element, default is 0
- **pos** ([Float/Percent, Float/Percent]): alternative way to specify the position by the location of the anchor point
- **anchor** ([Float/Percent, Float/Percent]): anchor point, default is ["50%", "50%"]
- **w** (Float, Percent or "fill"): width of the element, default is "100%".
- **h** (Float, Percent or "fill"): height of the element, default is "100%"
- **bc** (Color): background color, default is *clear*, animatable
- **clip** (Boolean): Specifies clipping behavior, default is false
- **borderWidth** (Float): Width of the border, default is 0, animatable
- **borderColor** (Color): Color of the border, animatable
- **cornerRadius** (Float): Size of the corner radius, animatable
- **opacity** (Float): Opacity of the element, between 0 to 1, animatable
- **rotate** (Float or Float[3]): Rotation in degree around the anchor point, clockwise, default is 0, animatable. 
- **scale** (Float or [Float, Float]): Scaling factor around the anchor point, default is [1, 1], animatable
- **translate** ([Float, Float]): Translation, default is [0, 0], animatable
- **text** (String, [langId:String] or ["ref":StringId]): Text to display
  - **textAlign** (String or [String]): Text alignment, *center* (default), *left*, *right*, *top*, *bottom*, or *justified*
  - **fontSize** (Float or Percent): Font size
  - **fontName** (String or [String]): Font name or names (the first name existing in the system is used)
  - **textColor** (Color): Color of the text, animatable
- **markdown** (String or [String]): Markdown to display
- **img** (URL): Image to display, animatable
- **mask** (URL): Image mask (PNG with the alpha channel)
- **sprite** (URL): Sprite to display
  - **slice** ([Int, Int]): Dimension of the sprite
  - **slot** ([Int, Int]): Slot to display, animatable
- **path** (Path): Path to display (SVG style), animatable
  - **lineWidth** (Float): Width of stroke, default is 0
  - **strokeColor** (Color): Color of the stroke, default is black, animatable
  - **fillColor** (Color): Fill color, default is clear, animatable
  - **strokeStart** (Float): Starting offset, default is 0, animatable
  - **strokeEnd** (Float): Ending offset, default is 1, animatable
- **video** or **radio** (URL): Video/Radio to play
  - **videoStart** (Float): Starting point of the video in seconds, default is 0
  - **videoDuration** (Float): Ending point of the video in seconds
- **stream** (Bool): Specifies if the resource specified with the video tag is stream or not, default is false
- **to** (Transition Animation): Specifies the Transitional Animation
- **loop** (Loop Animation): Specifies the Loop Animation
- **tiling** (Bool): Specifies the tiling (to be used with *shift* loop animation)
- **action** (String): Specifies the action (only **play** is supported)
- **repeat** (Bool): Repeat rule for the element. The default is false.
- **shadow** (shadow properties): Specifies the shadow properties; *color* (Color, default is black), *offset* ([Float, Float], default is [1,1]), *opacity* (Float, default is 0.5) and *radius* (Float, default is 1.0). 
- **id** (String): Identifier used in Actions to reference the page
- **events** ([Event+]): List of Events and their associated Actions
- **enabled** (Bool): Specifies if events are enabled
- **list** (List): List of items (refer to the List section below)
- **textArea** (TextInput): Multiline text input box (refer to the TextArea section below)
- **data** (String or JSON): Application-defined data associated with the element.  May be referenced using **valueOf**
- **focusable** (Bool): For non-touch devices, such as a TV, this property specifies that the device can move focus to the element when set to *true*.  Otherwise, the focusing mechanism will ignore the element.  An element must be in focus to receive user input and fire the corresponding events.

### Element Events
- **tapped**: The user singled-tapped on the element. *Propagated*
- **doubleTapped**: The user double-tapped on the element. *Propagated*
- **gainedFocus**: The user moved focus to the element.
- **lostFocus**: The user moved focus away from the element.  
- **enabled**: Element **enabled** property set to **true**
- **disnabled**: Element **enabled** property set to **false**
- **focusable**: Element **focusable** property set to **true**
- **unfocusable**: Element **focusable** property set to **false**

**lostFocus** is always received before **gainedFocus**.

Unhandled element events are propagated to their parent (containing **element**).  If no **element** in the hierarchy handles the event, then the containing **page** receives the event.

### Element Template

**ElementTemplates** are a set of **Elements** defined in "elements" property of the **Document**. Any **Element** can inherit properties from one of those **ElementTemplates** by specifying its name in the "template" property.

The sample below uses a **ElementTemplate**, "smile" as a template for five different **Elements** in a page.

```
{
    "templates": {
        "elements": {
            "smile": {
                "lineWidth":3,
                "path":"M0,0 C10,50 90,50 100,0",
                "strokeColor":"red"
            }
        }
    },
    "pages": [
        {
            "elements": [
                { "template":"smile", "pos":["50%", 100] },
                { "template":"smile", "pos":["50%", 200], "rotate":30 },
                { "template":"smile", "pos":["50%", 300], "lineWidth":10 },
                { "template":"smile", "pos":["50%", 400], "strokeColor":"#37F" },
                { "template":"smile", "pos":["50%", 500], "scale":[2,1] }
            ]
        }
    ]
}
```

Just like a regular **Element**, **ElementTemplate** may have child **Elements**, and they will be deep-merged just like **Elements** in **PageTemplate**.

The following example shows how to use a **ElementTemplate** with child **Elements**, and override their properties using the "id" property.

```
{
    "templates": {
        "elements": {
            "helloWorld": {
                "w":160, "h":100,
                "elements":[
                    { "id":"hello", "text":"Hello", "textAlign":"left" },
                    { "id":"world", "text":"World", "textAlign":"left", "x":80 }
                ]
            }
        }
    },
    "pages": [
        {
            "elements": [
                { "template":"helloWorld", "pos":[160, 100] },
                { "template":"helloWorld", "pos":[160, 200],
                  "elements":[
                    { "id":"hello", "textColor":"red" },
                    { "id":"world", "textColor":"blue" }
                  ]},
                { "template":"helloWorld", "pos":[160, 300],
                  "elements":[
                    { "id":"world", "text":"Swipe!" }
                  ]}
            ]
        }
    ]
}
```

## 7. Transition Animation

The **Transition Animation** specifies a set of animations to play right after or during the page transition (depending on the "transition" property of the page).

The "to" property of each element specifies the animation to be performed on the element, by specifying a new value for animatable properties, such as "opacity", "rotate", "translate", "bc", "path", "pos" (the value should be a SVG style path, and the "translate" will be ignored), "mode". 

The "mode" property can be "auto", "reverse" or empty. "mode" applies only when "pos" specifies an animation path.  When "auto" is specified, the element's rotation matches the angle along the path.  When "reverse" is specified, the element's rotation is the reverse (rotated 180 degrees) of the angle along the path.  When "mode" is not specified or is empty, the element's rotation is not affected by the path.

The "timing" property specifies the timing of animation with two floating values, start and end (must be between 0.0 and 1.0). The default is [0.0, 1.0].

Following example animates the text "I'm animatable!" down when the second page appears on the screen. 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"I'm animatable!", "to":{ "translate":[0, 200] } }
            ]
        }
    ]
}
```
If the "play" property of the page is "auto" (which is default) like the sample above, the animation happens after the page scrolling, and the duration of the animation is determined by the "duration" property of the page (the default is 0.2 seconds). 

If the "play" property of the page is "scroll" like the example below, the animation takes place while the user swipes the previous page up to see this page, and the "duration" property of the page will be ignored (since the user's swipe action determines the duration). 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "play":"scroll",
            "elements": [
                { "text":"Hello World!", "to":{ "translate":[0, 200] } }
            ]
        }
    ]
}
```

## 8. Loop Animation

The "loop" property of the element specifies the **Loop Animation** associated with the element. Unlike **Transition Animation**, it repeats the same animation multiple times specified by the *count* property (the default is 1). 

The **Loop Animation** must have a "style" property, and the value of this property must be one of following.

- *vibrate*: The **Element** vibrates left to right, where the "delta" property specifies the distance (the default is 10)
- *blink*: The **Element** blinks changing its opacity from 1 to 0. 
- *wiggle*: The **Element** rotates left and right, where the "delta" property specifies the angle in degree (the default is 15)
- *spin*: The **Element** spins, where the "clockwise" property (boolean) specifies the direction, the default is true. 
- *shift*: The **Element** shift to the specified direction where the "direction" property specifies the direction ("n", "s", "e" or "w", the default is "s"). Use it with the "tiling" property.
- *path*: The **Element** performs path animation, where the "path" property specifies a collection of **Paths**. 
- *sprite*: The **Element** performs a sprite animation. 

The "timing" property of a loop animation specifies the timing of animation with two floating values, start and end (must be between 0.0 and 1.0). The default is [0.0, 1.0].
 
Following example wiggles the text "I'm wiggling!" three times when the second page appears on the screen. 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"I'm wiggling!", "loop":{ "style":"wiggle", "count":3 } }
            ]
        }
    ]
}
```

## 9. Accessing Property Values

JSON property values can be referenced using **valueOf**.

### Syntax
```
  "valueOf:{"id":ElementId, "property":String}"
```

**id** optionally specifies the **element**, **params** item, or **list** item to reference.  If **id** is not specified, then the enclosing **element** is referenced.

**property** specifies the name of the property to be referenced.

The type of the result matches the type of the referenced property.

Currently supported **element** Properties:
- **text**
- **text.length**
- **enabled**
- **data**
- **x**, **y**, **w**, **h**
- **screenX**: The screen-relative **x**
- **screenY**: The screen-relative **y**

Currently supported non-**element**s:
- **params**
- **list** **items**

### Examples

The example below displays 2 buttons ("one" and "two") and a text element with **id** of "echo".  When either button is tapped, the action updates "echo"'s **text** property with the button's **text** property using **valueOf**.

```
{
  "templates":{
    "elements": {
      "button":{
        "x":"10%", "w":"80%", "h":30, "bc":"#efe",
        "events":{
          "tapped":{ "actions":[ { "update":{ "id":"echo", "text":{"valueOf":{ "property":"text"} }}} ]}
        }
      }
    }
  },
  "pages":[
    {
      "play":"never",
      "elements":[
        { "template":"button", "text":"one", "y":50 },
        { "template":"button", "text":"two", "y":82 },
        { "id":"echo", "x":"10%", "y":114, "w":"80%", "h":30, "bc":"#eee" }
      ]
    }
  ]
}
```

## 10. Events and Actions

The **events** property and the corresponding **actions** property provide a way to respond to events.  Events can be generated internally by Swipe, such as the completion of an animation or timer, and by the user, such as taps on the screen.  An event contains the actions to be performed when the specified event occurs.

### Syntax
```
  "events":{
    Event:{
      "actions":[
        Action, Action, ...
      ]      
    },
    Event:{
      "params":Schema,
      "actions":[
        Action, Action, ...
      ]      
    },
    ...
  }
```

**Event** is the String name of the event.  The available events are specified in the sections throughout this document.  Some examples:

- **Page**: "loaded", "tapped", "doubleTapped"
- **Element**: "tapped", "doubleTapped"

**params** optionally define the JSON schema for data parameters provided by the **Event**.  The **params** can be referenced using **valueOf** (described later in this document).  Currently, **params** are not used to validate the **valueOf**.  A future release will validate.

**actions** specifies a list of actions to perform when the event occurs.  The actions are performed in the order listed.

### Element Actions
- **update**: Updates **element**'s properties

#### Update Action
Updates the specified **element**'s properties.  If no **element** is specified, then the enclosing **element**'s properties are updated.

Any **page** that use the **update** action must specify "play":"never" to avoid animation conflicts with **page** animations.

##### Syntax
```
  { "update": { "id":String, "search":Search Property:Value, Property:Value, ..., "duration":Float, "events":Events } }
```
**id** specifies the target **element** and is optional.  Wen **id** is specified, the **update** is performed on the first **element** in the parent hierarchy with a matching **id** (including the enclosing **element**).  If no **element** is found, the enclosing **page** searches its **elements** for a match.  When **id** is not specified, the **update** is performed on the enclosing **element**.

**search** determines if the search for a matching **element** should be performed up the parent/child hierarchy or from the current element to its child **element**s.  A **search** value of "children" specifies the latter.  When **search** is not specified, then search is down up the parent/child hierarchy.  If no element with the matching **id** is found when search up the parent child hierarchy, the containing page searches its child **elements** for a match.

**duration** specifies the animation duration in seconds.

If **events** is specified, the event **completion** occurs after the update has completed.  If **duration** is specified, then the **completion** event occurs after the time specified in **duration** has completed.

### Example

The example below updates the **element**'s **text** property to "tapped" when the user taps on the **element**.
```
{
    "pages": [
      {
        "play":"never", "//":"Required when using 'update' action",
        "elements": [
          {
            "text": "tap me",
            "pos": ["50%", "33%"],
            "w":"90%",
            "h":"10%",
            "bc":"#fdd",
            "events": {
              "tapped": {
                "actions": [
                  {
                    "update": {"text":"tapped"}
                  }
                ]
              }
            }
          }
        ]
      }
    ]
}
```

## 11. Element Focus
An **element** is in focus when the user highlights an item using a remote control or keyboard. Therefore, the notion of *focus* makes sense only on non-touch devices such as TVs.

The **element** becomes focused as the user navigates through the **focuasable** elements on the screen. In a focus-based interaction model, a single **element** onscreen is considered focused, and the user can move focus to other **element**s by navigating through the **element** onscreen using a remote control.  This navigation of **element**s triggers the **lostFocus** and **gainedFocus** events on the **element**s as the lose and gain focus. The focused **element** is used as the target of any user actions. For example, when an **element** is focused, the **tapped** is triggered when the user presses the **select** button on the remote.

The TV's focus engine automatically determines where focus should move in response to navigation events from a remote. Users can move focus in any two-dimensional direction: left, right, up, down, or diagonal (as supported by the remote/TV).

### Focus Highlighting
Highlighting the focused **element** can be done in many ways and is left to the app.  The following example uses a simple red focus rectangle to highlight the focused element.

```
{
  "templates":{
    "elements":{
      "button":{
        "data":"one", "h":50, "bc":"#ccc", "borderWidth":1, "borderColor":"#ccc", "cornerRadius":10, "focusable":true,  
        "events":{
          "load":{
            "actions":[
              { "update": {"text":{"valueOf":{"property":"data"}}} }
            ]
          },
          "gainedFocus":{
            "actions":[
              { 
                "update":{ 
                  "id":"focus", 
                  "x":{"valueOf":{"property":"screenX"}}, 
                  "y":{"valueOf":{"property":"screenY"}}, 
                  "w":{"valueOf":{"property":"w"}}, 
                  "h":{"valueOf":{"property":"h"}},
                  "opacity":1,
                  "duration":0.4
                } 
              }
            ]
          },
          "lostFocus":{
            "actions":[
              { 
                "update":{ 
                  "id":"focus", 
                  "opacity":0
                } 
              }
            ]
          },
          "tapped":{
            "actions":[
              { 
                "update":{ 
                  "text":"tapped", "bc":"#eee", "duration":0.4, 
                  "events":{
                    "completion":{
                      "actions":[
                        { "update": {"text":{"valueOf":{"property":"data"}}, "bc":"#ccc" } }
                      ]
                    }
                  }
                }
              }
            ]
          }
        }
      }
    }
  },
  "pages":[
    {
      "play":"never",
      "elements":[
        { "template":"button", "data":"1", "y":50 },
        { 
          "y":105, "h":"50", 
          "elements":[
            { "template":"button", "data":"2", "w":"50%" },
            { "template":"button", "data":"3", "x":"50%", "w":"50%" }
          ]
        },
        { "id":"focus", "borderWidth":2, "borderColor":"red", "opacity":0 }
      ]
    }
  ]
}
```

## 12. List Element

Displays a scrollable list of items.  The items are composed of **elements** that define the visual layout of each item.  Items also contain **data** which defines String to be displayed.  

### Syntax
```
  "elements": [
    {
      "list": {
        "selectedItem":Integer,
        "scrollEnabled":Boolean,
        "items": [
          { "elements":[ Element, ... ], "data":String or JSON },
          ...
        ]
      }
    }
  ]
```

**selectedItem** optionally specifies the initially selected item.  Items are numbering starts with 0 (zero).  The default is 0 (zero), the first item.

**scrollEnabled** optionally specifies whether the list items are scrollable.  Default is *true*.

**items** optionally specifies the initial items to be displayed.  **elements** define the visual layout of the item.  **data** typically is a string to be displayed and is referenced from the **elements** using "valueOf".  **data** can also be JSON and if it contains **elements** and **data** child elements, then the JSON is used to define the item, replacing the item definition.  This is done so that a server response can fully define the item.

### Events
- **rowSelected**: Notification when the selected item changes

### Actions
- **append**: appends one or more list items to the **list**

#### Syntax

```
{
  "append": {
    "id":String,
    "items": [
      { "elements":[ Element, ... ], "data":String or JSON},
      ...
    ]
}
```

### Examples
The example below displays a list and a text element that displays the currently selected list item.  When an item is tapped/selected, the **rowSelected** event occurs and the associated **action** updates the text element.

```
{
	"templates":{
		"elements":{
			"item":{	"bc":"#eef", "text":{"valueOf":{"id":"aList", "property":{"items":{"data":{"person":{"id":"first"}}}}}}}
		}
	},
	"pages":[
		{
			"id": "main",
			"play":"never",
			"elements":[
				{ "h":"8%", "w":"45%", "pos":["25%","95%"], "text":"selected", "textAlign":"right"},
				{ "id":"echo", "h":"8%", "w":"45%", "pos":["75%","95%"],"text":"2"},
				{
					"id": "aList",
					"h":"80%",
					"w":"90%",
					"bc":"#ffe",
					"pos":["50%","50%"],
					"list":{
						"selectedItem":2,
						"items":[
							{ "elements":[ {"template":"item" }], "data":{ "person": { "id": { "first":"fred", "last":"flintstone"}}}},
							{ "elements":[ {"template":"item" }], "data":{ "person": { "id": { "first":"wilma", "last":"flintstone"}}}},
							{ "elements":[ {"template":"item" }], "data":{ "person": { "id": { "first":"barney", "last":"rubble"}}}},
							{ "elements":[ {"template":"item" }], "data":{ "person": { "id": { "first":"betty", "last":"rubble"}}}}
						]
					},
					"events":{
						"rowSelected":{
							"actions":[
								{ "update":{ "id":"echo", "text":{"valueOf":{"id":"aList", "property":"selectedItem"}}}}
							]
						}
					}
				}
			]
		}
	]
}
```

## 13. TextArea Element

The **textArea** element defines a multi-line text input box where the user can enter text.  It's **text** property can be changed using the **update** action and referenced using **valueOf**.

### Syntax
```
{ "textArea":{}, ... }
```
Currently, the **value** is reserved for future use and must be set to "{}".

### Events
- **textChanged**: Occurs whenever the text is changed either by the user or via the **update** action.
- **endEdit**: Occurs when the user taps outside the **textArea**.

### Actions
- **update**

### Example
In the example below, text entered into the **textArea** is copied to the element with **id** "echo" when the user taps outside the **textArea**.

```
{
  "templates": {
    "elements": {
      "text": { "h":"10%", "w":"90%", "x":"5%", "y":"15%", "bc":"#eef" }
    }
  },
  "pages": [
    {
      "play":"never",
      "elements": [
        { "template":"text", "text":"Enter Text Below"},
        {
          "id":"input", "textArea":{}, "template":"text", "text":"hello", "h":"20%", "y":"55%",
          "events": {
            "endEdit": {
              "actions": [
                { "update": { "id":"echo", "text":{"valueOf":{"property":"text"}}}}
              ]
            }
          }
        },
        {
          "id":"echo", "template":"text", "h":"20%", "text":"", "y":"30%"
        }
      ]
    }
  ]
}
```

## 14. HTTP GET and POST 
The actions **get** and **post** provide ways to communication with an HTTP server.

### Get Syntax
```
  { "get":{ "source": {"url":String}, "events":Events }						
```

**url** specifies the URL to get.

### Post Syntax
```
  {"post":{ "target":{ "url":"url" }, "params":{ String:String, ... }, "headers":{String:String, ...}, "data":String or JSON, "events":Events }	
```
**url** specifies the URL of the receiver of the post.
**params** specifies URL parameter to be appended to **url**
**headers** specifies HTTP headers to be added to the POST request
**data** specifies the HTTP POST body as either a String or JSON.

### Events
- **error**: Occurs when an internal error is detected or if an HTTP error occurs.  The event's **params** must always be `{"message":{"type":"string"}}` 
- **completion**: Occurs when the HTTP request completes successfully.  Data is accessed via **params** which are dependent on the expected server response format.

### Example
In the example below, when the "HTTP GET" element is tapped, the **get** action GETs the JSON file from the server.  This response contains properties **caption** text and **imgURL** which are used to update the **text** and **img** properties of two elements to display the caption and image.
```
{
	"pages": [
		{
			"play":"never",
			"elements": [
				{
					"text":"HTTP GET", "pos":["50%", 80], "w":"80%", "h":40, "borderWidth":1, "borderColor":"black", "cornerRadius":10, 
					"events":{
						"tapped":{
							"actions":[
								{ "update":{"id":"label", "text":"Loading ..." } },
								{
									"get":{
										"source": {"url":"http://www.stoppani.net/swipe/simpledata.txt"},
										"events": {
											"error": {
												"params": {"message":{"type":"string"}},
												"actions": [
													{ "update":{"id":"label", "text":"** Error **"}},
													{ "update":{"id":"error", "text":{"valueOf":{"property":{"params":"message"}}, "opacity":1}}}
												]
											},
											"completion": {
												"params": {"caption":{"type":"string"}, "imageURL":{"type":"string"}},
												"actions": [
													{ "update":{"id":"label", "text":{"valueOf":{"property":{"params":"caption"}}}}},
													{ "update":{"id":"image", "img":{"valueOf":{"property":{"params":"imgURL"}}}}}
												]
											}
										}
									}
								}								
							]
						}
					}},
				{"id":"label", "h":40, "pos":["50%", 130] },
				{"id":"image", "w":150, "h":150, "pos":["50%", 240], "img":"more.png" },
				{"id":"error", "textColor":"red", "h":40, "pos":["50%", 20] }
			 ]
		}
  ]
}
```

The example below uses **post** to send "hello" to a chat bot and displays the response string.
```
{
  "post":{
    "target": {"url":"https://exampledomain.com/chatbot/talk/"},
    "headers": { "Authorization":"BASIC 000000000" },
    "data": { "text":"hello"},
    "events": {
      "error": {
        "params": {"message":{"type":"string"}},
        "actions": [
          { "update":{"id":"label", "text":"** Error **"}},
          { "update":{"id":"error", "text":{"valueOf":{"property":{"params":"message"}}, "opacity":1}}}
        ]
      },
      "completion": {
        "params": {"status":"string","response":"string","sessionid":"number"},
        "actions": [
          {	"update":{"id":"label", "text":{"valueOf":{"property":{"params":"responses"}}}} }
        ]
      }
    }
  }
}
```

## 15. Timers
The **timer** action provides a way to perform other actions based on timed intervals that may or may not repeat.

### Syntax
```
  { "timer": { "duration":1, "repeats":true, "events":Events } }
```

**duration** specifies the time interval in seconds
**repeats** specifies whether or not the timer continues to fire after the first **duration**.  The default is **false**

### Events
- **tick**: Occurs when the specified **duration** seconds have transpired.

### Example
In the example below, when the "tap me" element is tapped, a repeating timer with a duration of 1 sec is started.  The **text** then alternates between "tick" and "tock" every 30 seconds (due to the additional 0.5 sec update animation).  Also notice that the element is disabled so that it can receive the **tapped** event only once.

```
{
	"pages": [
		{
			"play":"never",
			"elements": [
				{
					"text": "tap me to start timer", "fontSize":20, "pos": ["50%", "33%"], "w":"90%", "h":"10%", "bc":"#fdd",
					"events": {
						"tapped": {
							"actions": [
								{
									"update": {
										"text":"tapped", "bc":"#fee",	"duration":0.5, 
										"events":{ 
											"completion":{
												"actions":[ { "update":{	"text":"tap me", "bc":"#fdd", "enabled":false	}	}	] 
											} 
										}
									}
								},
								{
									"timer": { 
										"duration":1, "repeats":true,
										"events":{
											"tick":{
												"actions":[
													{ "update":{ "text":"tick", "duration":0.5, "events":{ "completion":{ "actions":[	{ "update":{ "text":"tock" }}]}}}}
												]
											}
										}
									}
								}
							]
						}
					}
				}
			]
		}
  ]
}
```

## 16. Multilingual Strings

The "strings" property of the page specifies strings in multiple languages.  The format is:

```
	"strings": {StringId: {LangId:String, ...}}
```

"text" elements on the page can specify the string via the "ref" property which has the format:
```
	"text":{"ref":StringId}
```

Following example displays "good day" and "good evening" unless the locale is "de"; then "Guten Tag" and "guten Abend" are displayed. 

```
{
    "pages":[
        {
            "strings": { 
            	"good day": {"*":"good day", "de": "Guten Tag"},
            	"good evening": {"*":"good evening", "de": "guten Abend"}
            },
            	
            "elements":[
                { "text":{"ref":"good day"}, "h":"20%", "pos":["50%", "12%"]},
                { "text":{"ref":"good evening"}, "h":"20%", "pos":["50%", "34%"]}
            ]
        }
    ]
}
```

Alternatively, the "text" element can directly specify the strings for each language directly using the following format:
```
	"text":{ LangId:String, ...}
```

Following example displays "good morning" and "good afternoon" unless the locale is "de"; then "guten Morgen" and "guten Nachmittag" are displayed. 
```
{
    "pages":[
        {
            "elements":[
                { "text":{"*":"good morning", "de": "guten Morgen"}, "h":"20%", "pos":["50%", "12%"]},
                { "text":{"*":"good afternoon", "de": "guten Nachmittag"}, "h":"20%", "pos":["50%", "34%"]}
            ]
        }
    ]
}
```

To enable language selection in the Swipe viewer via the "Lang." button, use the **Document** property **languages** to list the available languages using the following format:

```
	"languages":[{"id":LangId, "title":String},...]
```

Example:
```
{ 
    "languages":[
        {"id": "en", "title": "English"},
        {"id": "de", "title": "German"}
    ],
    "pages":[
        {
            "elements":[
                { "text":{"*":"good morning", "de": "guten Morgen"}, "h":"20%", "pos":["50%", "12%"]},
                { "text":{"*":"good afternoon", "de": "guten Nachmittag"}, "h":"20%", "pos":["50%", "34%"]}
            ]
        }
    ]
}

```
