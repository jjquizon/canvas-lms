/*
 * Copyright (C) 2020 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import {render, fireEvent} from '@testing-library/react'
import React from 'react'
import {MessageDetailActions} from '../MessageDetailActions'

describe('MessageDetailItem', () => {
  it('sends the selected option to the provided callback function', () => {
    const props = {
      handleOptionSelect: jest.fn(),
      onReply: jest.fn()
    }
    const {getByRole, getByText} = render(<MessageDetailActions {...props} />)

    const replyButton = getByRole(
      (role, element) => role === 'button' && element.textContent === 'Reply'
    )
    fireEvent.click(replyButton)
    expect(props.onReply).toHaveBeenCalled()

    const moreOptionsButton = getByRole(
      (role, element) => role === 'button' && element.textContent === 'More options'
    )
    fireEvent.click(moreOptionsButton)
    fireEvent.click(getByText('Reply All'))
    expect(props.handleOptionSelect).toHaveBeenLastCalledWith('reply-all')
  })
})
